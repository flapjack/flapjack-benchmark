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
