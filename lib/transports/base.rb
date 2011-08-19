module Transport
  class Transport
    attr_accessor :open, :discarded, :id
    attr_accessor :name, :postEncoded

    def packet obj
      write parser.encodePacket obj
    end

    def handleRequest req
      log.debug 'setting request', req.method, req.url
      @req = req

      if req.method == 'GET'
        @socket = req.socket
        @open = true
        @drained = true
        setHeartbeatInterval
        setHandlers
        onSocketConnect
      end
    end

    def setHandlers
      # we need to do this in a pub/sub way since the client can POST the message
      # over a different socket (ie: different Transport instance)
      @store.on('heartbeat-clear:' + @id, methods(:onHeartbeatClear))
      @store.on('disconnect-force:' + @id, methods(:onForceDisconnect))
      @store.on('dispatch:' + @id, methods(:onDispatch))

      @socket.on('end', methods(:doEnd))
      ['close', 'error', 'drain'].each { | which |
        @socket.on(which, methods(which))
      }

      @handlersSet = true

    end

    def clearHandlers
      if @handlersSet
        ['disconnect-force', 'heartbeat-clear', 'dispatch'].each { | which |
          @store.unsubscribe("#{which}:#{@id}")
        }

        @socket.removeListener('end', methods(:doEnd))
        ['close', 'error', 'drain'].each { | which |
          @socket.removeListener(which, methods(which))
        }
      end
    end

    def onSocketConnect; end

    def onSocketClose err
      doEnd err
    end

    def onSocketError err
      if @open
        @socket.destroy
        onClose
      end

      log.info 'socket error'
    end

    def onSocketDrain
      @drained = true
    end

    def onHeartbeatClear
      clearHeartbeatTimeout
      setHeartbeatInterval
    end

    def onForcedDisconnect
      unless @disconnected
        log.info 'transport end by forced client disconnection'

        if @open
          packet :type => 'disconnect' 
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

        @closeTimeout = EventMachine::Timer.new(@manager.get('close timeout') * 1000) { | x |
          log.debug 'fired close timeout for client'
          @closeTimeout = nil
          doEnd 'close timeout'
        }
      end
      log.debug 'set close timeout for client'
    end

    def clearCloseTimeout
      unless @closeTimeout.nil?
        clearTimeout @closeTimeout
        @closeTimeout = nil

        log.debug 'cleared close timeout for client'
      end
    end

    def setHeartbeatTimeout
      if @heartbeatTimeout.nil?

        @heartbeatTimeout = EventMachine::Timer.new(@manager.settings('heartbeat timeout') * 1000) { | x |
          log.debug 'fired heartbeat timeout for client'
          @heartbeatTimeout = nil
          doEnd 'heartbeat timeout'
        }
        log.debug 'set heartbeat timeout for client'
      end
    end

    def clearHeartbeatTimeout
      unless @heartbeatTimeout.nil?
        clearTimeout @heartbeatTimeout
        @heartbeatTimeout = nil
        log.debug 'cleared heartbeat timeout for client'
      end
    end

    def setHeartbeatInterval
      if @heartbeatInterval.nil?
        @heartbeatInterval = EventMachine::Timer.new(@manager.settings('heartbeat interval') * 1000) { | x |
          heartbeat
          @heartbeatInterval = nil
        }
      end
      log.debug('set heartbeat interval for client')
    end

    def clearTimeouts
      clearCloseTimeout
      clearHeartbeatTimeout
      clearHeartbeatInterval
    end

    def heartbeat
      if @open
        log.debug 'emitting heartbeat for client'

        packet :type => :heartbeat 

        setHeartbeatTimeout
      end
    end

    def onMessage packet
      current = @manager.transports[@id]

      if 'heartbeat' == packet[:type]
        log.debug 'got heartbeat packet'

        if (current && current.open)
          current.onHeartbeatClear
        else
          @store.publish "heartbeat-clear:#{@id}"
        end
      else 
        if ('disconnect' == packet[:type] && packet[:endpoint] == '')
          log.debug 'got disconnection packet'

          if current
            current.onForcedDisconnect
          else
            @store.publish "disconnect-force:#{@id}"
          end

          return
        end

        if (packet[:id] && packet[:ack] != 'data') 
          log.debug 'acknowledging packet automatically'

          ack = Parser.encodePacket({
            :type => 'ack',
            :ackId => packet[:id],
            :endpoint => packet[:endpoint] || ''
          })

          if (current && current.open) 
            current.onDispatch ack
          else
            @manager.onClientDispatch @id, ack
            @store.publish "dispatch:#{@id}", ack
          end 
        end

        # handle packet locally or publish it
        if current
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
        log.debug 'cleared heartbeat interval for client', @id
      end
    end

    def disconnect reason
      packet :type => 'disconnect'
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
        @manager.onClose @id
        @store.publish 'close', @id
      end
    end

    def doEnd reason
      close
      clearTimeouts
      @disconnected = true

      if local
        @manager.onClientDisconnect @id, reason, true
      else 
        @store.publish 'disconnect:' + @id, reason
      end 
    end

    def discard 
      log.debug 'discarding transport'
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

      log.warn reason
      doEnd 'error'
    end

    def packet obj
      write Parser.encodePacket obj
    end

    def writeVolatile msg
      # don't think this is needed
    end
  end
end
