module EventEmitter

  def listeners(event = nil)
    (get event).map { | which | @registrar[which] }
  end

  def get(event = nil)
    # This is needed for once, unless
    # you have a better idea how to 
    # implement it
    @registrar ||= {}
    @registrar_index ||= 1

    @cbMap ||= {}
    @cbMap[event] ||= []
  end

  def on(event, &function)
    emit('newListener', [event, function])
    @registrar_index += 1
    @registrar[@registrar_index] = function
    (get event) << @registrar_index
    @registrar_index
  end

  def once(event, &function)
    id = on(event) { |*args|
      function.call(*args)
      removeListener(event, id) 
    }
  end

  def setMaxListeners(n); end

  alias addListener on

  def removeListener(event, function)
    if function.class == Fixnum
      get(event).reject! { | handle | handle == function }
    else
      get(event).reject! { | handle | @registrar[handle] == function }
    end
  end

  def removeAllListeners(event)
    get(event).each { | index |
      @registrar.delete index
    }
    get(event).clear
  end

  def emit(event, *args)
    get(event).each { | index |
      @registrar[index].call(*args)
    }
  end
end

