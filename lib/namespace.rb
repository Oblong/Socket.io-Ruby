
class SocketNamespace
  include EventEmitter

  alias emit _emit

  def initialize mgr, name
    @manager = mgr
    @name = name || ''
    @sockets = {}
    @auth = false
    setFlags
  end

  def clients room
    room = @name + (room.nil? ? ('/' + room) : '')

    return [] unless @manager.rooms[room]

    @manager.rooms[room].map! { |id| 
      socket id
    }
  end

  def log; @manager.log; end
  def store; @manager.store; end
  def json; @flags[:json] = true; end
  def volatile; @flags[:volatile] = true; end

  def in room
    @flags[:endpoint] = @name + (room.nil? ? '' : '/' + room )
  end

  def except id
    @flags[:exceptions] << id
  end

  def setFlags
    @flags = {
      :endpoint => @name,
      :exceptions => []
    }
    self
  end

  def _packet packet
    packet[:endpoint] = @name
    store = @store
    log = @log
    volatile = @flags[:volatile]
    exceptions = @flags[:exceptions]
    packet = Parser.encodePacket packet

    @manager.onDispatch @flags[:endpoint], packet, volatile, exceptions
    @store.publish 'dispatch', @flags[:endpoint], packet, volatile, exceptions

    setFlags

    self
  end

  def send data
    packet({
      :type => @flags[:json] ? 'json' : 'message',
      :data => data
    })
  end

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

  def socket(sid, readable=nil)
    @sockets[sid] = Socket.new(@manager, sid, self, readable) unless @sockets[sid]
  end

  def authorization fn
    @auth = fn
    self
  end

  def handleDisconnect sid, reason
    if @sockets[sid] && @sockets[sid][:readable]
      @sockets[sid].onDisconnect reason
    end
  end

  def authorize data, fn
    if @auth
      @auth.call(data, lambda { | err, authorized |
        log.debug('client ' + (authorized ? '' : 'un') + 'authorized for ' + @name)
        fn.call(err, authorized)
      })
    else
      log.debug "client authorized for #{@name}"
      fn nil, true
    end
    self
  end

  def handlePacket sessid, packet
    _socket = socket sessid
    dataAck = packet[:ack] = 'data'

    def ack(*args)
      log.debug 'sending data ack packet'

      _socket.packet({
        :type => 'ack',
        :args => args,
        :ackId => packet[:id]
      })
    end

    def doError err
      log.warn 'handshake error ' + err + ' for ' + @name

      _socket.packet({
        :type => 'error',
        :reason => err
      })
    end

    def connect
      @manager.onjoin sessid, @name
      @store.publish 'join', sessid, @name

      # packet echo
      _socket.packet({ 
        :type => 'connect' 
      })

      # emit connection event
      _emit 'connection', socket
    end

    case packet[:type]
    when 'connect'
      if packet[:endpoint] == ''
        connect
      else
        manager = @manager
        handshakeData = manager.handshaken[sessid]

        authorize handshakeData { |err, authorized, newData|
          if err 
            return doError err
          end

          if authorized
            manager.onHandshake sessid, newData || handshakeData
            @store.publish 'handshake', sessid, newData || handshakeData
            connect
          else
            doError 'unauthorized'
          end
        }
      end

    when 'ack'
      # TODO
      if _socket[:acks][packet[:ackId]]
        _socket[:acks][packet[:ackId]].call( _socket, packet.args )
      else
        log.info 'unknown ack packet'
      end 

    when 'event'
      params = [packet[:name]].concat(packet[:args])

      if dataAck
        params.push ack
      end

      _socket._emit _socket, params

    when 'disconnect'
      @manager.onLeave sessid, @name
      @store.publish 'leave', sessid, @name

      _socket._emit 'disconnect', packet[:reason] || 'packet'

    when 'json'
    when 'message'
      params = ['message', packet[:data]]

      if dataAck
        params.push ack
      end

      _socket._emit _socket, params
    end
  end 
end
