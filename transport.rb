module Transport
  class Transport
    attr_accessor :open, true
    attr_accessor :discarded, true
    attr_accessor :id, true
    attr_accessor :name, true
    attr_accessor :postEncoded, true

    def packet(obj)
      write parser.encodePacket(obj)
    end

    def handleRequest req
=begin
  this.log.debug('setting request', req.method, req.url);
  this.req = req;

  if (req.method == 'GET') {
    this.socket = req.socket;
    this.open = true;
    this.drained = true;
    this.setHeartbeatInterval();

    this.setHandlers();
    this.onSocketConnect();
  }
=end
    end

    def setHandlers
      # we need to do this in a pub/sub way since the client can POST the message
      # over a different socket (ie: different Transport instance)
      @store.onMany {
        'heartbeat-clear:' + this.id => { | x | onHeartbeatClear },
        'disconnect-force:' + this.id => { | x | onForcedDisconnect },
        'dispatch:' + this.id => onDispatch
      }

      @socket.onMany {
=begin
  this.bound = {
      end: this.onSocketEnd.bind(this)
    , close: this.onSocketClose.bind(this)
    , error: this.onSocketError.bind(this)
    , drain: this.onSocketDrain.bind(this)
  };

  this.socket.on('end', this.bound.end);
  this.socket.on('close', this.bound.close);
  this.socket.on('error', this.bound.error);
  this.socket.on('drain', this.bound.drain);

  this.handlersSet = true;
};

Transport.prototype.clearHandlers = function () {
  if (this.handlersSet) {
    this.store.unsubscribe('disconnect-force:' + this.id);
    this.store.unsubscribe('heartbeat-clear:' + this.id);
    this.store.unsubscribe('dispatch:' + this.id);

    this.socket.removeListener('end', this.bound.end);
    this.socket.removeListener('close', this.bound.close);
    this.socket.removeListener('error', this.bound.error);
    this.socket.removeListener('drain', this.bound.drain);
  }
};
=end
    def onSocketConnect; end

    def onSocketClose err; doEnd err; end

    def onSocketError err
      if @open
        @socket.destroy
        onClose
      end

      Logger.info('socket error') 
    end

    #Transport.prototype.onSocketDrain = function () {
    #  this.drained = true;
    #};

    def onHeartbeatClear
      clearHeartbeatTimeout
      setHeartbeatInterval
    end
=begin
Transport.prototype.onForcedDisconnect = function () {
  if (!this.disconnected) {
    this.log.info('transport end by forced client disconnection');
    if (this.open) {
      this.packet({ type: 'disconnect' });
    }
    this.end('booted');
  }
};

/**
 * Dispatches a packet.
 *
 * @api private
 */

Transport.prototype.onDispatch = function (packet, volatile) {
  if (volatile) {
    this.writeVolatile(packet);
  } else {
    this.write(packet);
  }
};

Transport.prototype.setCloseTimeout = function () {
  if (!this.closeTimeout) {
    var self = this;

    this.closeTimeout = setTimeout(function () {
      self.log.debug('fired close timeout for client', self.id);
      self.closeTimeout = null;
      self.end('close timeout');
    }, this.manager.get('close timeout') * 1000);

    this.log.debug('set close timeout for client', this.id);
  }
};

/**
 * Clears the close timeout.
 */

Transport.prototype.clearCloseTimeout = function () {
  if (this.closeTimeout) {
    clearTimeout(this.closeTimeout);
    this.closeTimeout = null;

    this.log.debug('cleared close timeout for client', this.id);
  }
};

/**
 * Sets the heartbeat timeout
 */

Transport.prototype.setHeartbeatTimeout = function () {
  if (!this.heartbeatTimeout) {
    var self = this;

    this.heartbeatTimeout = setTimeout(function () {
      self.log.debug('fired heartbeat timeout for client', self.id);
      self.heartbeatTimeout = null;
      self.end('heartbeat timeout');
    }, this.manager.get('heartbeat timeout') * 1000);

    this.log.debug('set heartbeat timeout for client', this.id);
  }
};

/**
 * Clears the heartbeat timeout
 *
 * @param text
 */

Transport.prototype.clearHeartbeatTimeout = function () {
  if (this.heartbeatTimeout) {
    clearTimeout(this.heartbeatTimeout);
    this.heartbeatTimeout = null;
    this.log.debug('cleared heartbeat timeout for client', this.id);
  }
};

/**
 * Sets the heartbeat interval. To be called when a connection opens and when
 * a heartbeat is received.
 *
 * @api private
 */

Transport.prototype.setHeartbeatInterval = function () {
  if (!this.heartbeatInterval) {
    var self = this;

    this.heartbeatInterval = setTimeout(function () {
      self.heartbeat();
      self.heartbeatInterval = null;
    }, this.manager.get('heartbeat interval') * 1000);

    this.log.debug('set heartbeat interval for client', this.id);
  }
};
=end
    def clearTimeouts
      clearCloseTimeout
      clearHeartbeatTimeout
      clearHeartbeatInterval
    end

    def heartbeat
      if @open
        Logger.debug('emitting heartbeat for client')
        packet({ :type => :heartbeat })
        setHeartbeatTimeout
      end
    end

    def onMessage packet
=begin
  var current = this.manager.transports[this.id];

  if ('heartbeat' == packet.type) {
    this.log.debug('got heartbeat packet');

    if (current && current.open) {
      current.onHeartbeatClear();
    } else {
      this.store.publish('heartbeat-clear:' + this.id);
    }
  } else {
    if ('disconnect' == packet.type && packet.endpoint == '') {
      this.log.debug('got disconnection packet');

      if (current) {
        current.onForcedDisconnect();
      } else {
        this.store.publish('disconnect-force:' + this.id);
      }

      return;
    }

    if (packet.id && packet.ack != 'data') {
      this.log.debug('acknowledging packet automatically');

      var ack = parser.encodePacket({
          type: 'ack'
        , ackId: packet.id
        , endpoint: packet.endpoint || ''
      });

      if (current && current.open) {
        current.onDispatch(ack);
      } else {
        this.manager.onClientDispatch(this.id, ack);
        this.store.publish('dispatch:' + this.id, ack);
      }
    }

    // handle packet locally or publish it
    if (current) {
      this.manager.onClientMessage(this.id, packet);
    } else {
      this.store.publish('message:' + this.id, packet);
    }
  }
=end
    end

=begin
Transport.prototype.clearHeartbeatInterval = function () {
  if (this.heartbeatInterval) {
    clearTimeout(this.heartbeatInterval);
    this.heartbeatInterval = null;
    this.log.debug('cleared heartbeat interval for client', this.id);
  }
};
=end
    def disconnect reason
      packet({ :type => 'disconnect'})
      doEnd reason
    end

    def close
      if open
        doClose
        onClose
      end
    end


    def onClose
      if open
        setCloseTimeout
        clearHandlers
        @open = false
        #manager.onClose(@id)
        @store.publish(close, id)
      end
    end

    def doEnd reason
      close
      clearTimeouts
      @disconnected = true
=begin
    if (local) {
      this.manager.onClientDisconnect(this.id, reason, true);
    } else {
      this.store.publish('disconnect:' + this.id, reason);
    }
=end
    end

    def discard 
      Logger.debug 'discarding transport'
      @discarded = true
      clearTimeouts
      clearHandlers
    end

    def doError(reason, advice)
      packet({
        :type => 'error',
        :reason => reason,
        :advice => advice
      })

      Logger.warn(reason)
      doEnd('error')
    end

    def packet obj
      write Parser.encodePacket(obj)
    end

    def writeVolatile msg
      # don't think this is needed
    end

  end
end
