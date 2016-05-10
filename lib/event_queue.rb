require 'timeout'

def wait_until_empty_queue(redis)
  Timeout.timeout(10) do
    sleep(1) while redis.llen('events') > 0
  end
end

def event_queue_redis_connection
  redis_config = Flapjack::Benchmark::Config.redis_config

  Redis.new(
    host: redis_config['host'],
    port: redis_config['port'],
    db: redis_config['db']
  )
end

# TODO: Consider removing 'use_multi' - it doesn't appear to make any significant change in performance
def push_event(redis: nil, queue: 'events', event: nil, repeat: 1, use_multi: true)
  raise 'Redis connection not defined' unless redis
  raise 'Event not defined' unless event

  event[:time] = Time.now.to_i if event[:time].nil?

  event_json = JSON.generate(event)

  if use_multi && (repeat > 1)
    redis.multi do |multi|
      repeat.times do
        multi.lpush(queue, event_json)
      end
    end

    # NOTE Required by Flapjack 2.0. Pushing a nonsense value into `events_actions` will trigger
    # processing the contents of the `events` queue
    redis.lpush('events_actions', 'x') if Flapjack::VERSION == '2.0.0'
  else
    repeat.times do
      redis.lpush(queue, event_json)
      redis.lpush('events_actions', 'x') if Flapjack::VERSION == '2.0.0'
    end
  end
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
