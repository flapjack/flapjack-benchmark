def guarantee_cycle(next_time)
  yield
  raise 'Block took longer than cycle time' if Time.now > next_time
  while Time.now < next_time
    # Do nothing
  end
end

def tick_cycle(seconds, count)
  next_time = Time.now + seconds
  (1..count).each do |cycle_number|
    guarantee_cycle(next_time) do
      yield cycle_number
    end
    next_time += seconds
  end
end
