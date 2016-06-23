require 'performance_test'
require 'minitest/autorun'
require 'test_server'
require 'config'
require 'redis'
require 'event_queue'
require 'rubygems'

require 'flapjack'
require 'flapjack/redis_proxy'
require 'flapjack/record_queue'

require 'flapjack/data/condition'
require 'flapjack/data/check'
require 'flapjack/data/extensions/associations'
require 'flapjack/data/extensions/short_name'
require 'flapjack/data/medium'
require 'flapjack/data/notification'
require 'flapjack/data/rule'

require 'stackprof'


class NotificationsTest < PerformanceTest

  def setup
    @redis = event_queue_redis_connection
    @redis.flushdb
    Thread.current[:flapjack_redis] = @redis
    Zermelo.redis = @redis
    @notifier_queue = Flapjack::RecordQueue.new(
      'notifications',
      Flapjack::Data::Notification
    )
  end

  def teardown

  end

  # def test_naive_load_1_notifications
  #   naive_load_notifications(count: 1)
  # end

  def test_naive_load_100_notifications
    naive_load_notifications(count: 100)
  end

  def test_naive_load_500_notifications
    naive_load_notifications(count: 500)
  end

  def test_naive_load_1000_notifications
    naive_load_notifications(count: 1000)
  end

  private


  def naive_load_notifications(count: 0)

    $VERBOSE = nil

    puts "Naive load for #{count} notifications\n"
    media = Flapjack::Data::Medium.new(
      transport: 'email',
      address: 'foobarmail.com',
      interval: 0,
      rollup_threshold: 10000
    )
    media.save!

    rule = Flapjack::Data::Rule.new(
      :name => 'test_rule',
      :enabled => true,
      :blackhole => false,
      :strategy => 'global',
      :conditions_list => 'critical',
      :has_media => true
    )

    rule.save!
    rule.media << media
    rule.save!

    contact = Flapjack::Data::Contact.new(
      :name => 'test_contact',
      :timezone => "Australia/Adelaide"
    )

    contact.save!
    contact.media << media
    contact.rules << rule
    contact.save!

    check = Flapjack::Data::Check.new(
      :id => '20f182fc-6e32-4794-9007-97366d162c51',
      :name => 'foobar:ping',
      :enabled => true,
      :alertable => true
    )
    check.save!

    state = Flapjack::Data::State.new(
      :created_at    => Time.now,
      :updated_at    => Time.now,
      :condition     => 'critical',
      :action        => 'test_notifications'
    )
    state.save!
    state.check = check
    state.save!

    data_load_start = Time.now
    count.times do
      notification = Flapjack::Data::Notification.new(
        :condition_duration    => 16.0,
        :severity          => 'critical',
        :type              => 'problem',
        :time              => Time.now,
        :duration          => 10,
      )

      notification.save!
      notification.state = state
      notification.save!

      check.notifications << notification
      check.save!
      @notifier_queue.push(notification)
    end
    data_load_end = Time.now
    puts "\tData load time: #{data_load_end - data_load_start} seconds"

    puts 'PAUSING!'
    sleep(10)
    Flapjack::Benchmark::TestServer.start

    puts "\tFlapjack Server started."
    begin
      processing_start = nil

      queue_length = @redis.llen('notifications')
      while queue_length > 0
        # Look for first 'pop' from queue
        if processing_start.nil? && queue_length < count
          processing_start = Time.now
        end
        sleep(2)
        queue_length = @redis.llen('notifications')
      end
      processing_end = Time.now
      if processing_start
        puts "\tProcessing time: #{processing_end - processing_start} seconds"
      else
        puts "\tUnable to calculate processing time (processing_start missing)"
      end
    ensure
      Flapjack::Benchmark::TestServer.stop
      sleep(10)
    end

  end
end
