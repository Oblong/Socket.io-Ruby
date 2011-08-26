# socket.io-ruby
# Copyright(c) 2011 Oblong <chris@oblong.com>
# MIT Licensed
#
# Derived from
# socket.io-node
# Copyright(c) 2011 LearnBoost <dev@learnboost.com>
# MIT Licensed

# This is basically a shell for the http driven transports of
# xhr-polling
module Transports
  class HttpPolling < Transports::HTTPTransport
    def initialize(msg, data, req)
      super
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
        @timer = nil
        log.debug 'clearing poll timeout'
      end
    end

    def clearTimeouts
      super
      clearPollTimeout
    end

    def doWrite
      clearPollTimeout
    end
    
    def write(data, close)
      doWrite data
      @response.doEnd
      onClose
    end

    def end
      clearPollTimeout
      super # return HTTPTransport.prototype.end.call(this);
    end
  end
end
