
class SocketNamespace
# TODO
#SocketNamespace.prototype.__proto__ = EventEmitter.prototype;
#SocketNamespace.prototype.$emit = EventEmitter.prototype.emit;
  def initialize mgr, name
    @manager = mgr
    @name = name || ''
    @sockets = {}
    @auth = false
    setFlags
  end

  def clients room
    room = @name + (room.nil? '/' + room : '')

    return [] unless @manager[:rooms][room]

    # TODO
    @manager.rooms[room].map { |id| {
      return @socket(@id)
    }
  end

  def log; @manager.log; end
  def store; @manager.store; end
  def json 
    @flags[:json] = true
    self
  end

  def volatile
    @flags[:volatile] = true
    self
  end

  def in room
    @flags[:endpoint] = @name + (room.nil? ? '' : '/' + room )
    self
  end

  def except id
    @flags[:exceptions].push id
    self
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

  def socket sid, readable
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
      #TODO
      @auth(data, { | err, authorized |
        Logger.debug('client ' + (authorized ? '' : 'un') + 'authorized for ' + @name)
        fn(err, authorized);
      })
    else
      Logger.debug "client authorized for #{@name}"
      fn nil, true
    end
    self
  end

  def handlePacket sessid, packet
    socket = @socket sessid
    dataAck = packet[:ack] = 'data'

    def ack(*args)
      Logger.debug 'sending data ack packet'

      socket.packet({
        :type => 'ack',
        :args => args,
        :ackId => packet[:id]
      })
    end

    def doError err
      Logger.warn 'handshake error ' + err + ' for ' + @name

      socket.packet({
        :type => 'error',
        :reason => err
      })
    end

    def connect
      @manager.onjoin sessid, @name
      @store.publish 'join', sessid, @name

      # packet echo
      socket.packet({ :type => 'connect' })

      # emit connection event
      _emit 'connection', socket
    end

    case packet[:type]
    when 'connect'
      if packet[:endpoint] == ''
        connect
      else
        manager = @manager
        handshakeData = manager[:handshaken][sessid];

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
      if socket[:acks][packet[:ackId]]
        socket[:acks][packet[:ackId]] socket, packet.args
      else
        Logger.info 'unknown ack packet'
      end 

    when 'event'
      params = [packet[:name]].concat(packet[:args])

      if dataAck
        params.push ack
      end

      socket._emit socket, params

    when 'disconnect'
      @manager.onLeave sessid, @name
      @store.publish 'leave', sessid, @name

      socket._emit 'disconnect', packet[:reason] || 'packet'

    when 'json'
    when 'message'
      params = ['message', packet[:data]]

      if dataAck
        params.push ack
      end

      socket._emit socket, params
    end
  end 
end
