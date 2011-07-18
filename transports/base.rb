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
      # this.log.debug('setting request', req.method, req.url);
      # this.req = req;
      if req.method == 'GET'
        #this.socket = req.socket;
        #this.open = true;
        #this.drained = true;
        setHeartbeatInterval
        setHandlers
        onSocketConnect
      end
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
=end
    def setCloseTimeout
      if @closeTimeout.nil?

        @closeTimeout = EventMachine::Timer.new(Manager.settings['close timeout'] * 1000) do | x |
          Logger.debug('fired close timeout for client')
          @closeTimeout = nil
          doEnd 'close timeout'
      end
      Logger.debug('set close timeout for client')
    end

    def clearCloseTimeout
      unless @closeTimeout.nil?
        clearTimeout @closeTimeout
        @closeTimeout = nil

        Logger.debug('cleared close timeout for client')
      end
    end

    def setHeartbeatTimeout
      if @heartbeatTimeout.nil?

        @heartbeatTimeout = EventMachine::Timer.new(Manager.settings['heartbeat timeout'] * 1000) do | x |
          Logger.debug('fired heartbeat timeout for client')
          @heartbeatTimeout = nil
          doEnd 'heartbeat timeout'
        end
        Logger.debug('set heartbeat timeout for client')
      end
    end

    def clearHeartbeatTimeout
      unless @heartbeatTimeout.nil?
        clearTimeout @heartbeatTimeout
        @heartbeatTimeout = nil
        Logger.debug('cleared heartbeat timeout for client')
      end
    end

    def setHeartbeatInterval
      if @heartbeatInterval.nil?
        @heartbeatInterval = EventMachine::Timer.new(Manager.settings['heartbeat interval'] * 1000) do | x |
          heartbeat
          @heartbeatInterval = nil
        end
      end
      Logger.debug('set heartbeat interval for client')
    end

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

    def clearHeartbeatInterval 
      unless @heartbeatInterval.nil?
        clearTimeout @heartbeatInterval
        @heartbeatInterval = nil
        Logger.debug('cleared heartbeat interval for client', this.id)
      end
    end

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
