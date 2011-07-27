
class SocketNamespace
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

    
    return this.manager.rooms[room].map(function (id) {
      return this.socket(id);
    }, this);
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
    packet {
      :type => @flags[:json] ? 'json' : 'message',
      :data => data
    }
  end

  def emit(*name)
=begin
    if (name == 'newListener') {
      return this.$emit.apply(this, arguments);
    }
=end
    packet {
      :type => 'event',
      :name => name[0],
      :args => name[1..-1]
    }
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
=begin
/**
 * Performs authentication.
 *
 * @param Object client request data
 * @api private
 */

SocketNamespace.prototype.authorize = function (data, fn) {
  if (this.auth) {
    var self = this;

    this.auth.call(this, data, function (err, authorized) {
      self.log.debug('client ' +
        (authorized ? '' : 'un') + 'authorized for ' + self.name);
      fn(err, authorized);
    });
  } else {
    this.log.debug('client authorized for ' + this.name);
    fn(null, true);
  }

  return this;
};

/**
 * Handles a packet.
 *
 * @api private
 */

SocketNamespace.prototype.handlePacket = function (sessid, packet) {
  var socket = this.socket(sessid)
    , dataAck = packet.ack == 'data'
    , self = this;

  function ack () {
    self.log.debug('sending data ack packet');
    socket.packet({
        type: 'ack'
      , args: util.toArray(arguments)
      , ackId: packet.id
    });
  };

  function error (err) {
    self.log.warn('handshake error ' + err + ' for ' + self.name);
    socket.packet({ type: 'error', reason: err });
  };

  function connect () {
    self.manager.onJoin(sessid, self.name);
    self.store.publish('join', sessid, self.name);

    // packet echo
    socket.packet({ type: 'connect' });

    // emit connection event
    self.$emit('connection', socket);
  };

  switch (packet.type) {
    case 'connect':
      if (packet.endpoint == '') {
        connect();
      } else {
        var manager = this.manager
          , handshakeData = manager.handshaken[sessid];

        this.authorize(handshakeData, function (err, authorized, newData) {
          if (err) return error(err);

          if (authorized) {
            manager.onHandshake(sessid, newData || handshakeData);
            self.store.publish('handshake', sessid, newData || handshakeData);
            connect();
          } else {
            error('unauthorized');
          }
        });
      }
      break;

    case 'ack':
      if (socket.acks[packet.ackId]) {
        socket.acks[packet.ackId].apply(socket, packet.args);
      } else {
        this.log.info('unknown ack packet');
      }
      break;

    case 'event':
      var params = [packet.name].concat(packet.args);

      if (dataAck)
        params.push(ack);

      socket.$emit.apply(socket, params);
      break;

    case 'disconnect':
      this.manager.onLeave(sessid, this.name);
      this.store.publish('leave', sessid, this.name);

      socket.$emit('disconnect', packet.reason || 'packet');
      break;

    case 'json':
    case 'message':
      var params = ['message', packet.data];

      if (dataAck)
        params.push(ack);

      socket.$emit.apply(socket, params);
  };
};
