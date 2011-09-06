# socket.io-ruby
# Copyright(c) 2011 Oblong <chris@oblong.com>
# MIT Licensed
#
# Derived from
# socket.io-node
# Copyright(c) 2011 LearnBoost <dev@learnboost.com>
# MIT Licensed

class SocketNamespace
  # rb only
  attr_accessor :name

  # Constructor.
  # 
  # @api public.
  def initialize mgr, name
    @manager = mgr
    @name = name || ''
    @sockets = {}
    @auth = false
    setFlags
  end

  # Inherits from EventEmitter.
  include EventEmitter

  # Copies emit since we override it
  # 
  # @api private
  alias _emit emit

  # Retrieves all clients as Socket instances as an array.
  #
  # @api public
  def clients room
    room = @name + (room.nil? ? ('/' + room) : '')

    return [] if @manager.rooms[room].nil?

    @manager.rooms[room].map! do |id| 
      socket id
    end
  end

  # Access logger interface.
  # 
  # @api public
  def log
    @manager.log
  end

  # Access store.
  # 
  # @api public
  def store 
    @manager.store
  end

  # JSON message flag.
  # 
  # @api public
  def json 
    @flags[:json] = true
  end

  # Volatile message flag.
  # 
  # @api public
  def volatile 
    @flags[:volatile] = true
  end

  # Overrides the room to relay messages to (flag)
  # 
  # @api public
  def in room
    @flags[:endpoint] = @name + (room.nil? ? '' : '/' + room )
  end

  # Adds a session id we should prevent relaying messages to (flag)
  # 
  # @api public
  def except id
    @flags[:exceptions] << id
  end

  # Sets the default flags.
  # 
  # @api private
  def setFlags
    @flags = {
      :endpoint => @name,
      :exceptions => []
    }
  end

  # Sends out a packet
  # 
  # @api private
  def _packet packet
    packet[:endpoint] = @name
    log = @log
    volatile = @flags[:volatile]
    exceptions = @flags[:exceptions]
    packet = Parser.encodePacket packet

    @manager.onDispatch @flags[:endpoint], packet, volatile, exceptions
    store.publish 'dispatch', @flags[:endpoint], packet, volatile, exceptions

    setFlags
  end

  # Sends to everyone.
  # 
  # @api public
  def send data
    packet({
      :type => @flags[:json] ? 'json' : 'message',
      :data => data
    })
  end

  # Emits to everyone (override)
  # 
  # @api private
  def emit(*name)
    if name[0] == 'newListener'
      return _emit name
    end

    packet({
      :type => 'event',
      :name => name[0],
      :args => name[1..-1]
    })
  end

  # Retrieves or creates a write-only socket for a client, unless specified.
  # 
  # @param [Boolean] whether the socket will be readable when initialized
  # @api private
  def socket(sid, readable = nil)
    unless @sockets[sid]
      @sockets[sid] = Socket.new(@manager, sid, self, readable) 
    end

    @sockets[sid]
  end

  # Sets authorization for this namespace
  # 
  # @api public
  def authorization fn
    @auth = fn
  end

  # Called when a socket disconnects entirely.
  # 
  # @api private
  def handleDisconnect sid, reason
    if @sockets[sid] and @sockets[sid].readable
      @sockets[sid].onDisconnect reason
    end
  end

  # Performs authentication.
  #
  # @param Object client request data
  # @api private
  def authorize(data, &fn)
    if @auth
      @auth.call(data, lambda { | err, authorized |
        log.debug('client ' + (authorized ? '' : 'un') + 'authorized for ' + @name)
        fn.call(err, authorized)
      })
    else
      log.debug "client authorized for #{@name}"
      fn.call( nil, true )
    end
  end

  # Handles a packet
  #
  # @api private
  def handlePacket sessid, packet
    _socket = socket(sessid)
    dataAck = packet.ack = 'data'

    def ack(*args)
      log.debug 'sending data ack packet'

      _socket.packet({
        :type => 'ack',
        :args => args,
        :ackId => packet[:id]
      })
    end

    def doError(err, _socket)
      log.warn 'handshake error ' + err + ' for ' + @name

      _socket.packet({
        :type => 'error',
        :reason => err
      })
    end

    def connect(sessid, _socket)
      @manager.onJoin(sessid, @name)
      $stderr.puts "FROM HERE"
      store.publish('join', sessid, @name)

      # packet echo
      _socket.packet({ 
        :type => 'connect' 
      })

      # emit connection event
      _emit('connection', _socket)
    end

    case packet[:type]
    when 'connect'
      if packet.endpoint == ''
        connect(sessid, _socket)
      else
        manager = @manager
        handshakeData = manager.handshaken[sessid]

        authorize(handshakeData) do |err, authorized, newData|
          if err 
            return doError(err, _socket)
          end

          if authorized
            manager.onHandshake(sessid, newData || handshakeData)
            store.publish('handshake', sessid, newData || handshakeData)
            connect(sessid, _socket)
          else
            doError('unauthorized', _socket)
          end
        end
      end

    when 'ack'
      if _socket.acks[packet[:ackId]]
        _socket.acks[packet[:ackId]].call( packet[:args] )
      else
        log.info 'unknown ack packet'
      end 

    when 'event'
      params = [packet[:name]].concat(packet[:args])

      params << ack if dataAck

      _socket._emit(_socket, params)

    when 'disconnect'
      @manager.onLeave sessid, @name
      store.publish 'leave', sessid, @name

      _socket._emit('disconnect', packet.reason || 'packet')

    when 'json'
    when 'message'
      params = ['message', packet[:data]]

      params << ack if dataAck

      _socket._emit(_socket, params)
    end
  end 

end
