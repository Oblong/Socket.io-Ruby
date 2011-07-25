# This is basically a shell for the http driven transports of
# xhr-polling
module Tranport
  class HttpPolling < Transport::HTTPTranport
    def initialize(msg, data, req)
      super(msg, data, req)
      @name = 'httppolling'
    end

    def setHeartbeatInterval; end

    def handleRequest req
      if req.method == 'GET'
        @timer = EventMachine::Timer.new(Manager.settings['polling duration'] * 1000) do | x |
          packet({
            :type => :noop
          })
        end
      end
    end

    def clearPollTimeout
      unless @timer.nil?
        @timer.cancel 
        @timer = nil;
        Logger.debug 'clearing poll timeout'
      end
    end

    def clearTimeouts
      super()
      clearPollTimeout
    end

    def doWrite
      clearPollTimeout
    end
    
    def write(data, close)
      doWrite data
      @response.end
      onClose
    end

    def end
      clearPollTimeout
      super() # return HTTPTransport.prototype.end.call(this);
    end
  end
end
