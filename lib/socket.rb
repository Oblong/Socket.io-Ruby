# socket.io-ruby
# Copyright(c) 2011 Oblong <chris@oblong.com>
# MIT Licensed
#
# Derived from
# socket.io-node
# Copyright(c) 2011 LearnBoost <dev@learnboost.com>
# MIT Licensed

class Socket

  # Default error event listener to prevent uncaught exceptions.
  def defaultError
  end

  # Socket constructor.
  #
  # @param [Manager] manager instance
  # @param [String] session id
  # @param [Namespace] namespace the socket belongs to
  # @param [Boolean] whether the 
  # @api public
  def initialize manager, id, nsp, readable
    @manager = manager
    @id = id
    @namespace = nsp
    @ackPackets = 0
    @acks = {}
    @disconnected = false
    setFlags
    @readable = readable
    @store = @manager.store.client @id
    on('error', method(:defaultError))
  end

  # Inherits from EventEmitter.
  include EventEmitter

  # Accessor shortcut for the handshake data
  #
  # @api private
  def handshake 
    @manager.handshaken[@id]
  end

  # Accessor shortcut for the logger.
  # 
  # @api private
  def log
    @manager.log
  end

  # JSON message flag.
  #
  # @api public
  def json
    @flags.json = true
  end

  # Volatile message flag.
  #
  # @api public
  def volatile
    @flags.volatile = true
  end

  # Broadcast message flag.
  #
  # @api public
  def broadcast
    @flags.broadcast] = true
  end

  # Overrides the room to broadcast messages to (flag)
  #
  # @api public
  def to room
    @flags[:room] = room
  end

  # Resets flags
  #
  # @api private
  def setFlags
    @flags = {
      :endpoint => @namespace[:name],
      :room => ''
    }
  end

  # Triggered on disconnect
  #
  # @api private
  def onDisconnect reason
    unless @disconnected
      _emit 'disconnect', reason
      @disconnected = true
    end
  end

  # Joins a user to a room.
  #
  # @api public
  def join name, fn
    nsp = @namespace[:name]
    name = (nsp + '/') + name

    @manager.onJoin @id, name
    @manager.store.publish 'join', @id, name

    if fn
      log.warn 'Client#join callback is deprecated'
      fn
    end
  end

  # Un-joins a user from a room.
  #
  # @api public
  def leave name, fn
    nsp = @namespace[:name]
    name = (nsp + '/') + name

    @manager.onLeave @id, name
    @manager.store.publish 'leave', @id, name

    if fn
      log.warn 'Client#join callback is deprecated'
      fn
    end
  end

  # Transmits a packet.
  #
  # @api private
  def packet _packet
    if @flags[:broadcast]
      log.debug 'broadcasting packet'
      @namespace.in(@flags[:room]).except(@id).packet(_packet)
    else
      packet[:endpoint] = @flags[:endpoint]
      packet = Parser.encodePacket packet

      dispatch packet, @flags[:volatile]
    end

    setFlags
  end

  # Dispatches a packet
  #
  # @api private
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

  # Stores data for the client.
  #
  # @api public
  def set key, value, fn
    @store.set key, value, fn
  end

  # Retrieves data for the client
  #
  # @api public
  def get key, fn
    @store.get key, fn
  end

  # Checks data for the client
  #
  # @api public
  def has key, fn
    @store.has key, fn
  end

  # Deletes data for the client
  #
  # @api public
  def del key, fn
    @store.del key, fn
  end

  # Kicks client
  #
  # @api public
  def disconnect
    unless @disconnected
      log.info 'booting client'
      if (not @manager.transports[@id].nil?) and @manager.transports[@id].open
        @manager.transports[@id].onForcedDisconnect
      else
        @manager.onClientDisconnect @id
        @manager.store.publish "disconnect:#{@id}"
      end
    end
  end

  # Send a message.
  #
  # @api public
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

  # Original emit function.
  #
  # @api private
  alias _emit emit

  # Emit override for custom events.
  #
  # @api public
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
