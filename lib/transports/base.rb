# socket.io-ruby
# Copyright(c) 2011 Oblong <chris@oblong.com>
# MIT Licensed
#
# Derived from
# socket.io-node
# Copyright(c) 2011 LearnBoost <dev@learnboost.com>
# MIT Licensed

module Transports
  class Base
    include JS
    attr_accessor :open, :discarded, :id
    attr_accessor :name, :postEncoded
    attr_accessor :disconnected, :id, :manager

    # Transport constructor.
    #
    # @api public
    def initialize(mng, data, req = nil)
      # rb only
      @funMap = {}

      @manager = mng
      @id = data[:id]
      @disconnected = false
      @drained = true

      # rb only
      @response = @req.res unless @res.nil?

      handleRequest req unless req.nil?
    end

    # Access the logger.
    #
    # @api public
    def log
      @manager.log
    end

    # Access the store.
    #
    # @api public
    def store
      @manager.store
    end

    def packet obj
      write parser.encodePacket obj
    end

    # Handles a request when it's set.
    #
    # @api private
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

    # Sets transport handlers
    #
    # @api private
    def setHandlers
      # we need to do this in a pub/sub way since the client can POST the message
      # over a different socket (ie: different Transport instance)
      @funMap['heartbeat-clear'] = store.on('heartbeat-clear:' + @id) do 
        onHeartbeatClear
      end

      @funMap['disconnect-force'] = store.on('disconnect-force:' + @id) do
        onForceDisconnect
      end

      @funMap['dispatch'] = store.on('dispatch:' + @id) do 
        onDispatch
      end

      @funMap['end'] = @socket.on('end') do
        doEnd
      end

      @funMap['close'] = @socket.on('close') do
        close
      end

      @funMap['error'] = @socket.on('error') do
        error
      end

      @funMap['drain'] = @socket.on('drain') do
        onSocketDrain
      end

      @handlersSet = true

    end

    # Removes transport handlers
    #
    # @api private
    def clearHandlers
      if @handlersSet
        ['disconnect-force', 'heartbeat-clear', 'dispatch'].each { | which |
          store.unsubscribe("#{which}:#{@id}", @funMap[which])
        }

        ['end', 'close', 'error', 'drain'].each { | which |
          @socket.removeListener(which, @funMap[which])
        }
      end
    end

    def onSocketConnect; end

    # Called when the connection dies
    #
    # @api private
    def onSocketEnd
      doEnd 'socket end'
    end

    # Called when the connection dies
    #
    # @api private
    def onSocketClose err
      doEnd err
    end

    # Called when the connection has an error.
    #
    # @api private
    def onSocketError err
      if @open
        @socket.destroy
        onClose
      end

      log.info 'socket error'
    end

    # Called when the connection is drained.
    #
    # @api private
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

        @closeTimeout = setTimeout(@manager.get('close timeout') * 1000) do
          log.debug 'fired close timeout for client'
          @closeTimeout = nil
          doEnd 'close timeout'
        end
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

        @heartbeatTimeout = setTimeout(@manager.settings('heartbeat timeout') * 1000) do
          log.debug 'fired heartbeat timeout for client'
          @heartbeatTimeout = nil
          doEnd 'heartbeat timeout'
        end

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
        @heartbeatInterval = setTimeout(@manager.settings('heartbeat interval') * 1000) do
          heartbeat
          @heartbeatInterval = nil
        end
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

        packet :type => 'heartbeat'

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
          store.publish('heartbeat-clear:' + @id)
        end
      else 
        if 'disconnect' == packet.type and packet[:endpoint] == ''
          log.debug 'got disconnection packet'

          if current
            current.onForcedDisconnect
          else
            store.publish('disconnect-force:' + @id)
          end

          return
        end

        if packet[:id] and packet[:ack] != 'data'
          log.debug 'acknowledging packet automatically'

          ack = Parser.encodePacket({
            :type => 'ack',
            :ackId => packet[:id],
            :endpoint => packet.endpoint || ''
          })

          if (current and current.open) 
            current.onDispatch ack
          else
            @manager.onClientDispatch @id, ack
            store.publish('dispatch:' + @id, ack)
          end 
        end

        # handle packet locally or publish it
        if current
          @manager.onClientMessage @id, packet
        else
          store.publish('message:' + @id, packet)
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

    # Finishes the connection and makes sure client doesn't reopen
    #
    # @api private
    def disconnect reason
      packet :type => 'disconnect'
      doEnd reason
    end

    # Closes the connection.
    #
    # @api private
    def close
      if open
        doClose
        onClose
      end
    end

    # Called upon a connection close.
    #
    # @api private
    def onClose
      if open
        setCloseTimeout
        clearHandlers
        @open = false
        @manager.onClose @id

        store.publish('close', @id)
      end
    end

    # Cleans up the connection, considers the client disconnected.
    # 
    # @api private
    def doEnd(reason = nil)
      unless @disconnected
        log.info('transport end')

        # TODO
        local = @manager.transports[@id]

        close
        clearTimeouts
        @disconnected = true

        if local
          @manager.onClientDisconnect(@id, reason, true)
        else 
          store.publish('disconnect:' + @id, reason)
        end 
      end
    end

    # Signals that the transport should pause and buffer data.
    #
    # @api public
    def discard 
      log.debug 'discarding transport'
      @discarded = true
      clearTimeouts
      clearHandlers
    end

    # Writes an error packet with the specified reason and advice.
    #
    # @param [FixNum] advice
    # @param [FixNum] reason
    # @api public
    def doError(reason, advice)
      packet({
        :type => 'error',
        :reason => reason,
        :advice => advice
      })

      log.warn reason
      doEnd 'error'
    end

    # Write a packet.
    #
    # @api private
    def packet obj
      write Parser::encodePacket(obj)
    end

    # Writes a volatile message.
    #
    # @api private
    def writeVolatile msg
      # don't think this is needed
    end
  end
end
