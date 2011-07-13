# This is basically a shell for the http driven transports of
# xhr-polling
module Tranport
  class HttpPolling < Transport::Tranport
    def setHeartbeatInterval; end
    def handleRequest
      @timer = EventMachine::Timer.new(Manager.settings['polling duration'] * 1000) do | x |
        packet({
          :type => :noop
        })
      end
    end

    def clearPollTimeout
      @timer.cancel unless @timer.is_nil?
      Logger.debug 'clearing poll timeout'
    end

    def clearTimeouts; end
    def doWrite
      clearPollTimeout
    end
    
    def write
      clearPollTimeout
    end

    def end
      super()
      clearPollTimeout
    end
  end
end
