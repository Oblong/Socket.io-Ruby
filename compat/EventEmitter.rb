module EventEmitter

  def listeners(event = nil)
    # This is needed for once, unless
    # you have a better idea how to 
    # implement it
    @registrar ||= {}
    @registrar_index ||= 1

    @cbMap ||= {}
    @cbMap[event] ||= []
  end

  def on(event, function)
    emit('newListener', [event, function])
    @registrar_index += 1
    @registrar[@registrar_index] = function
    (listeners event) << @registrar_index
    @registrar_index
  end

  def once(event, function)
    id = on(event, lambda { |*args|
      function.call(*args)
      removeListener(event, id) 
    })
  end

  def setMaxListeners(n); end

  alias addListener on

  def removeListener(event, function)
    if function.class == Fixnum
      listeners(event).reject! { | handle | handle == function }
    else
      listeners(event).reject! { | handle | @registrar[handle] == function }
    end
  end

  def removeAllListeners(event)
    listeners(event).each { | index |
      @registrar.delete index
    }
    listeners(event).clear
  end

  def emit(event, *args)
    listeners(event).each { | index |
      @registrar[index].call(*args)
    }
  end
end

class Test
  include EventEmitter

  def initialize; end
end

a = Test.new

def fun(x)
  puts x 
end

def fun1(x)
  puts "HEllo" + x
end

a.once("something", method(:fun))
a.emit("something", "of value")
a.once("something", method(:fun1))
a.emit("something", "of value")
a.emit("something", "of value")
