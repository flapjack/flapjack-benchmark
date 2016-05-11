require 'redis'
require 'json'
require 'descriptive_statistics'
require 'performance_test'
require 'minitest/autorun'

require 'timing'
require 'config'
require 'event_queue'
require 'test_server'

# Array with fixed length, rolling values if maximum reached
class RollingArray < Array
  attr_reader :max

  def initialize(max)
    @max = max
  end

  def push(obj)
    self.<<(obj)
  end

  def <<(obj)
    shift if length == @max
    super
  end
end

class NaiveFloodTest < PerformanceTest
  def setup
    @redis = event_queue_redis_connection

    @redis.flushdb
    sleep(5)

    Flapjack::Benchmark::TestServer.start

    wait_until_empty_queue(@redis)
  end

  def teardown
    Flapjack::Benchmark::TestServer.stop
  end

  def test_ping_flood_100_per_sec
    ping_flood(event_rate: 100)
  end

  def test_ping_flood_120_per_sec
    ping_flood(event_rate: 120)
  end

  def test_ping_flood_150_per_sec
    ping_flood(event_rate: 150)
  end

  def test_ping_flood_200_per_sec
    ping_flood(event_rate: 200)
  end

  def test_ping_flood_500_per_sec
    ping_flood(event_rate: 500)
  end

  def test_ping_flood_1000_per_sec
    ping_flood(event_rate: 1000)
  end

  def test_find_equilibrium
    find_equilibrium(initial_event_rate: 0)
  end

  def test_find_peak_usage
    # NOTE You may need to play around with gain factors to get a reasonable equilibrium value.
    find_peak_usage(
      gain_factor: 0.5
    )
  end

  private

  def ping_flood(event_rate: 100)
    puts "Ping flood test: #{event_rate} events/sec..."

    queue_lengths = []
    tick_cycle(1, 40) do |_cycle_number|
      queue_lengths.push(fetch_queue_length(@redis))
      event = build_event(state: :ok)
      push_event(redis: @redis, event: event, repeat: event_rate)
    end

    cooling_down_start = Time.now

    puts "\n\tfinal queue length: #{queue_lengths.last}"
    puts "\tmean queue length: #{queue_lengths.mean}"

    current_queue_length = fetch_queue_length(@redis)
    next_time = Time.now + 1
    while current_queue_length > 0 # SMELL Repeat until would be better
      guarantee_cycle(next_time) do
        current_queue_length = fetch_queue_length(@redis)
      end
      next_time += 1
    end

    puts "\tcooling down time: #{Time.now - cooling_down_start} seconds\n\n"
  end

  def find_peak_usage(gain_factor: 0.5)
    puts 'Peak usage test'
    # Setup event gain
    event_gain = 10

    gain_error_history = []
    max_gain_error_history = 20

    # Setup intial state
    current_event_rate = 50
    current_queue_length = 0
    event_rate_history = []

    cycle_count = 1
    next_time = Time.now + 1

    (1..200).each do
      guarantee_cycle(next_time) do
        # Get queue length data
        last_queue_length     = current_queue_length
        current_queue_length  = fetch_queue_length(@redis)

        # Determine gain error
        gain_error = last_queue_length - current_queue_length

        # Calculate proportional gain from current cycle
        proportional_gain = (gain_error_history.last || 0) * gain_factor

        # # Store event gain error history
        gain_error_history.push(gain_error)
        gain_error_history.shift if gain_error_history.count > max_gain_error_history

        event_gain += proportional_gain.round
        event_gain = 1 if event_gain == 0 # Don't let event rate flatline

        current_event_rate += event_gain
        event_rate_history << current_event_rate

        # Push events at current rate
        event = build_event(state: :ok)
        push_event(redis: @redis, event: event, repeat: current_event_rate)
      end
      cycle_count += 1
      next_time += 1
    end

    puts "\tmax. event rate: #{event_rate_history.max}"
  end

  def find_equilibrium(initial_event_rate: 10, ramp_direction: :up)
    puts "Equilibrium test: initial push rate: #{initial_event_rate} events/sec; ramp: #{ramp_direction}..."
    # Determine throughput equilibrium
    # Ramp-up to equilibrium
    event_rate = initial_event_rate
    last_queue_length = 0
    ramp_rate = 10
    throughput_samples = RollingArray.new(50)
    max_variance = 4.0 # NOTE Arbitrary value - good enough

    event = build_event
    next_time = Time.now + 1

    equilibrium_reached = false

    until equilibrium_reached
      guarantee_cycle(next_time) do
        queue_length = fetch_queue_length(@redis)

        throughput_samples.push(event_rate)

        if throughput_samples.length == throughput_samples.max
          if throughput_samples.variance < max_variance
            puts "\tMean ping throughput: #{throughput_samples.mean} events/sec"
            equilibrium_reached = true
            break
          end
        end

        if queue_length <= last_queue_length
          ramp_rate -= 1 unless ramp_rate == 1 || ramp_direction == :up
          event_rate += ramp_rate
        else
          ramp_rate -= 1 unless ramp_rate == 1 || ramp_direction == :down
          event_rate -= ramp_rate
        end

        last_queue_length = queue_length

        (1..event_rate).each do
          event = build_event(state: :ok)
          push_event(redis: @redis, event: event)
        end
      end

      next_time += 1
    end
  end
end
