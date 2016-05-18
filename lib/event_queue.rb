require 'timeout'

def wait_until_empty_queue(redis)
  Timeout.timeout(10) do
    sleep(1) while redis.llen('events') > 0
  end
end

def event_queue_redis_connection
  redis_settings = Flapjack::Benchmark::Config.settings['redis']

  Redis.new(
    host: redis_settings['host'],
    port: redis_settings['port'],
    db:   redis_settings['db'],
    driver: :hiredis
  )
end

def push_event(redis: nil, queue: 'events', event: nil, repeat: 1)
  raise 'Redis connection not defined' unless redis
  raise 'Event not defined' unless event

  event[:time] = Time.now.to_i if event[:time].nil?

  event_json = JSON.generate(event)

  redis.multi do |multi|
    repeat.times do
      multi.lpush(queue, event_json)
    end
  end

  # NOTE Required by Flapjack 2.0. Pushing a nonsense value into
  # `events_actions` will trigger processing the contents of the `events`
  # queue
  redis.lpush('events_actions', 'x') if Flapjack::VERSION == '2.0.0'
end

def build_event(entity: 'foobar', check: 'ping', state: :ok)
  {
    entity: entity,
    check: check,
    type: 'service',
    state: state.to_s,
    time: Time.now.to_i
  }
end

def fetch_queue_length(redis)
  redis.llen('events')
end
