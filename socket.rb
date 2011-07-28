class Socket

  def initialize manager, id, nsp, readable
    @manager = manager
    @id = id
    @namespace = nsp
    @readable = readable
    @ackPackets = 0
    @acks = {}
    @disconnected = false
    setFlags
    @store = @manager.store.client @id
  end

  # getters
  def handshake; @manager.handshaken[@id]; end
  def log; @manager.log; end

  def json; @flags[:json] = true; end
  def volatile; @flags[:volatile] = true; end
  def broadcast; @flags[:broadcast] = true; end

  def to room
    @flags[:room] = room
  end

  def setFlags
    @flags = {
      :endpoint => @namespace[:name],
      :room => ''
    }
  end

  def onDisconnect reason
    unless @disconnected
      _emit 'disconnect', reason
      @discconnected = true
    end
  end

  def join name, fn
    nsp = @namespace[:name]
    name = (nsp + '/') + name

    @manager.onJoin @id, name
    @manager.store.publish 'join', @id, name

    if fn
      Logger.warn 'Client#join callback is deprecated'
      fn
    end
  end

  def leave name, fn
    nsp = @namespace[:name]
    name = (nsp + '/') + name

    @manager.onLeave @id, name
    @manager.store.publish 'leave', @id, name

    if fn
      Logger.warn 'Client#join callback is deprecated'
      fn
    end
  end

  def packet _packet
    if @flags[:broadcast]
      Logger.debug 'broadcasting packet'
      #this.namespace.in(this.flags.room).except(@id).packet(packet);
    else
      packet[:endpoint] = @flags[:endpoint]
      packet = Parser.encodePacket packet

      dispatch packet, @flags[:volatile]
    end

    setFlags
  end

  def dispatch packet, volatile
    if (not @manager.transports[@id].nil?) and @manager.transports[@id].open
      @manager.transports[@id].onDispatch packet, volatile
    else
      unless volatile
        @manager.onClientDispatch @id, packet, volatile
      end
    end

    @manager.store.publish "dispatch:#{@id}", packet, volatile
  end

  def set key, value, fn
    @store.set key, value fn
  end

  def get key, fn
    @store.get key, fn
  end

  def has key, fn
    @store.has key, fn
  end

  def del key, fn
    @store.del key, fn
  end

  def disconnect
    unless @disconnected
      Logger.info 'booting client'
      if (not @manager.transports[@id].nil?) and @manager.transports[@id].open
        @manager.transports[@id].onForcedDisconnect
      else
        @manager.onClientDisconnect @id
        @manager.store.publish "disconnect:#{@id}"
      end
    end
  end

  def send(data, fn=nil)
    _packet = {
      :type => @flags[:json] ? 'json' : 'message',
      :data => data
    }
    unless fn.nil?
      @ackPackets += 1
      _packet[:id] = @ackPackets
      _packet[:ack] = true
      @acks[_packet[:id]] = fn
    end

    packet _packet
  end

  ## TODO
  Socket.prototype._emit = EventEmitter.prototype.emit;

  def emit(*ev)
    if ev[0] == 'newListener'
      return _emit ev
    end

    args = ev[1..-1]
    lastArg = ev.last

    _packet = {
      :type => 'event',
      :name => ev
    }

    if Method == lastArg.class
      @ackPackets += 1
      _packet[:id] = @ackPackets
      _packet[:ack] = lastArg.length ? 'data' : true
      @acks[_packet[:id]] = lastArg
      args = args[0..-2]
    end 

    _packet[:args] = args

    packet _packet
  end
end
