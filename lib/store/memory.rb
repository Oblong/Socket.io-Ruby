class Memory < Store
  include EventEmitter

  def initialize(*opts)
    super
  end

  alias subscribe on
  def publish; end
  def unsubscribe; end
end

class Client < Store
  def initialize(*arguments)
    super
    @data = {}
  end

  def get key, fn
    fn(nil, @data[key])
    self
  end

  def set(key, value, fn=nil)
    @data[key] = value
    fn
    self
  end

  def has key, fn
    fn(nil, @data[key])
  end

  def del key, fn
    @data.delete key
    fn
    self
  end

  def destroy(expiration=nil)
    if expiration.nil?
      @data = {}
    else
      @closeTimeout = EventMachine::Timer.new(Manager.settings['close timeout'] * 1000) do | x |
        @data = {}
      end
    end
  end
end
