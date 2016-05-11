require 'logger'
require 'redis'
require 'descriptive_statistics'
require 'flapjack-diner'
# require "mini-smtp-server"
require 'securerandom'

require 'timing'
require 'config'
require 'event_queue'
require 'test_server'
require 'performance_test'
require 'minitest/autorun'

require 'pry'
require 'pry-byebug'

class OutageTest < PerformanceTest
  def setup
    @redis = event_queue_redis_connection

    puts 'Flushing DB..'
    @redis.flushdb
    sleep(5)

    setup_flapjack_diner

    Flapjack::Benchmark::TestServer.start
  end

  def teardown
    Flapjack::Benchmark::TestServer.stop
  end

  def test_outage_flood_100_per_sec
    outage_flood(event_rate: 100)
  end

  def test_outage_flood_200_per_sec
    outage_flood(event_rate: 200)
  end

  def test_outage_flood_500_per_sec
    outage_flood(event_rate: 500)
  end

  def test_outage_flood_1000_per_sec
    outage_flood(event_rate: 500)
  end

  private

  def setup_flapjack_diner
    base_uri = Flapjack::Benchmark::Config.jsonapi_config['base_url']
    logger_path = File.join(Flapjack::Benchmark::Config.log_path, 'diner.log')

    Flapjack::Diner.base_uri(base_uri)
    Flapjack::Diner.logger = Logger.new(logger_path, :error)
    Flapjack::Diner.open_timeout(30)
    Flapjack::Diner.read_timeout(600)
  end

  # TODO: Complete this test, removing reliance on threads by using a rolling
  # window, i.e. roll through groups of entities at the declared event rate,
  # posting initial CRITICAL checks (at half the event_rate?) and then posting
  # follow up CRTICAL checks in the group of entities that were initially hit
  # 30 seconds ago. It's a bit hard to explain, but the long and the short is
  # to perform the same tests as outage_flood, just without relying on threads
  def outage_flood_no_threads(event_rate: 100)
    puts "Outage flood test: #{event_rate} events/sec...\n"

    contacts = setup_contacts
    setup_media(contacts)
    entities = setup_entities(1000, contacts)

    puts "\tSetting initial check state"
    set_initial_check_state(@redis, entities)
    puts "\tSleeping for 30 seconds"
    sleep(30)

    puts "\tStarting outage run"

    #  initial_
  end

  def outage_flood(event_rate: 100)
    puts "Outage flood test: #{event_rate} events/sec..."

    contacts = setup_contacts
    setup_media(contacts)
    entities = setup_entities(1000, contacts)

    puts 'Setting initial check state'
    set_initial_check_state(@redis, entities)
    sleep(30)

    outage_start_time = Time.now

    puts 'Sleeping'
    sleep(30)
    puts "\tStarting initial event run..."
    Thread.new { flood_entities_with_ping_critical(entities, event_rate) }
    puts "\tSleeping main thread..."
    sleep(40)
    puts "\tStarting followup event run..."
    mean_queue_length = flood_entities_with_ping_critical(entities, event_rate)
    puts "\tSleeping main thread..."
    sleep(40)
    outage_recovery_start_time = Time.now
    puts "\tSend recovery events..."
    create_initial_check_state_ping_ok(@redis, entities)
    puts "\n\tmean queue length: #{mean_queue_length}"

    outage_recovery_end_time = Time.now

    puts "\toutage_start_time: #{outage_start_time}"
    puts "\toutage_recovery_start_time: #{outage_recovery_start_time}"
    puts "\toutage_recovery_end_time: #{outage_recovery_end_time}"
  end

  def flood_entities_with_ping_critical(entities, event_rate)
    redis = event_queue_redis_connection

    queue_lengths = []
    next_time = Time.now + 1
    entities.each_slice(event_rate) do |entities_slice|
      queue_lengths.push(redis.llen('events'))
      guarantee_cycle(next_time) do
        entities_slice.each do |entity|
          event = build_event(entity: entity[:id], state: :critical)
          push_event(redis: redis, event: event)
        end
      end
      next_time += 1
    end

    queue_lengths.mean
  end

  def create_initial_check_state_ping_ok(redis, entities)
    entities.each do |entity|
      event = build_event(entity: entity[:id], state: :ok)
      push_event(redis: redis, event: event)
    end
  end

  def build_contacts(count)
    (1..count).inject([]) do |memo|
      memo << case Flapjack::VERSION
              when '1.6.0' then build_contact_1_6_0
              when '2.0.0' then build_contact_2_0_0
              else
                raise "Unsupported Flapjack::VERSION #{Flapjack::VERSION}"
              end
    end
  end

  # SMELL Use a mixin or alias to switch between Flapjack version-specific
  # code.
  def build_contact_1_6_0
    {
      id: SecureRandom.uuid,
      first_name: SecureRandom.base64(21),
      last_name: SecureRandom.base64(21),
      email: "#{SecureRandom.base64(21)}@example.bulletproof.net"
    }
  end

  def build_contact_2_0_0
    {
      id: SecureRandom.uuid,
      name: SecureRandom.base64(21)
    }
  end

  def build_media(contacts)
    contacts.inject([]) do |memo, contact|
      memo << {
        id: SecureRandom.uuid,
        transport: 'email',
        address: "#{SecureRandom.base64(21)}@example.bulletproof.net",
        interval: 3,
        contact: contact[:id]
      }
    end
  end

  def build_entities(count, contacts)
    contact_ids = contacts.map { |c| c[:id] }

    (1..count).inject([]) do |memo|
      memo << {
        id: SecureRandom.uuid,
        name: SecureRandom.base64(21),
        contacts: contact_ids
      }
    end
  end

  def create_contacts(contacts)
    Flapjack::Diner.create_contacts(*contacts)
  end

  # SMELL Use a mixin or alias to switch between Flapjack version-specific
  # code.
  def create_media(media)
    case Flapjack::VERSION
    when '1.6.0' then create_media_1_6_0(media)
    when '2.0.0' then Flapjack::Diner.create_media(*media)
    else
      raise "Unsupported Flapjack::VERSION #{Flapjack::VERSION}"
    end
  end

  def create_media_1_6_0(media)
    media.each do |medium|
      medium_hash = {
        type: medium[:transport],
        address: medium[:address],
        interval: medium[:interval],
        rollup_threshold: 30 # SMELL Arbitrary value
      }

      Flapjack::Diner.create_contact_media(medium[:contact], [medium_hash])
    end
  end

  def setup_contacts
    contacts = build_contacts(10)

    success = create_contacts(contacts)

    raise 'Error importing contacts into Flapjack' unless success

    contacts
  end

  def setup_media(contacts)
    contact_media = build_media(contacts)
    success = create_media(contact_media)

    raise 'Unable to create media' unless success

    contact_media
  end

  def setup_entities(count, contacts)
    # For FJ 2.0 we don't bother to import entities (doesn't make sense),
    # but for 1.6 we will. So, for 2.0 just pass through to the build_entities
    # method
    build_entities(count, contacts)
  end

  def set_initial_check_state(redis, entities)
    entities.each do |entity|
      event = build_event(entity: entity[:id], state: :ok)
      push_event(redis: redis, event: event)
    end
  end
end
