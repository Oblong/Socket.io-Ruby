# EventEmitter-ruby
# Copyright(c) 2011 Oblong <chris@oblong.com>
# MIT Licensed

module EventEmitter

  def listeners(event = nil)
    (_get event).map do | which | 
      @registrar[which] 
    end
  end

  def on(event, &function)
    emit('newListener', [event, function])
    @registrar_index += 1
    @registrar[@registrar_index] = function
    (_get event) << @registrar_index
    @registrar_index
  end

  def once(event, &function)
    id = on(event) do |*args|
      function.call(*args)
      removeListener(event, id) 
    end 
  end

  def setMaxListeners(n); end

  alias addListener on

  def removeListener(event, function)
    if function.class == Fixnum
      _get(event).reject! do | handle | 
        handle == function 
      end
    else
      _get(event).reject! do | handle | 
        @registrar[handle] == function
      end
    end
  end

  def removeAllListeners(event)
    _get(event).each do | index |
      @registrar.delete index
    end 

    _get(event).clear
  end

  def emit(event, *args)
    _get(event).each do | index |
      @registrar[index].call(*args)
    end 
  end

  # Duplication because socket.io likes
  # to override the emit
  def _emit(event, *args)
    _get(event).each do | index |
      @registrar[index].call(*args)
    end 
  end

  private

  def _get(event = nil)
    # This is needed for once, unless
    # you have a better idea how to 
    # implement it
    @registrar ||= {}
    @registrar_index ||= 1

    @cbMap ||= {}
    @cbMap[event] ||= []
  end
end

