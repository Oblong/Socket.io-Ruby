module Transport
  class Transport
    attr_accessor :open, true
    def onSocketConnect; end

    def packet(obj)
      write(parser.encodePacket(obj)
    end

    def doWrite(data); end
    def handleRequest(req); end
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
        #store.publish(close, id
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
=begin
  this.log.debug('discarding transport');
  this.discarded = true;
  this.clearTimeouts();
  this.clearHandlers();

  return this;
=end
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
  end
end
