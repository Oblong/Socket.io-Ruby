module Transport
  class Transport
    attr_accessor :open, :discarded, :id
    attr_accessor :name, :postEncoded

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
=end
    def clearHandlers
      if @handlersSet
        ['disconnect-force', 'heartbeat-clear', 'dispatch'].each { | which |
          @store.unsubscribe("#{which}:#{@id}")
        }

        ['end', 'close', 'error'].each { | which |
          @socket.removeListener which, ### TBD
=begin
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

    def onForcedDisconnect
      unless @disconnected
        Logger.info('transport end by forced client disconnection');
        if @open
          packet({ :type => 'disconnect' })
        end

        doEnd 'booted'
      end
    end

    def onDispatch packet, volatile
      if volatile
        writeVolatile packet 
      else
        write packet
      end
    end

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
      current = @manager.transports[@id]

      if 'heartbeat' == packet.type
        Logger.debug 'got heartbeat packet'

        if (current && current.open)
          current.onHeartbeatClear
        else
          @store.publish("heartbeat-clear:#{@id}")
        end
      else 
        if ('disconnect' == packet.type && packet.endpoint == '')
          Logger.debug 'got disconnection packet'

          if (current) 
            current.onForcedDisconnect
          else
            @store.publish "disconnect-force:#{@id}"
          end

          return
        end

        if (packet.id && packet.ack != 'data') 
          Logger.debug 'acknowledging packet automatically'

          ack = Parser.encodePacket {
              :type => 'ack'
            , :ackId => packet.id
            , :endpoint => packet.endpoint || ''
          }

          if (current && current.open) 
            current.onDispatch ack
          else
            @manager.onClientDispatch @id, ack
            @store.publish "dispatch:#{@id}", ack
          end 
        end

        # handle packet locally or publish it
        if (current)
          @manager.onClientMessage @id, packet
        else
          @store.publish "message:#{@id}", packet
        end
      end
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
