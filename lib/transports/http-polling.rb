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

    # HTTP polling constructor.
    #
    # @api public.
    def initialize(mng, data, req)
      super
      @name = 'httppolling'
    end

    # Removes heartbeat timeouts for polling.
    def setHeartbeatInterval; end

    # Handles a request
    # 
    # @api private
    def handleRequest req
      if req.method == 'GET'
        puts @manager.get 'polling duration' 

        @timer = setTimeout(@manager.get('polling duration') * 1000) do 
          packet({
            :type => :noop
          })
        end
      end
    end

    # Clears polling timeout
    #
    # @api private
    def clearPollTimeout
      unless @timer.nil?
        clearTimeout @timer
        @timer = nil
        log.debug 'clearing poll timeout'
      end
    end

    # Override clear timeouts to clear the poll timeout
    # 
    # @api private
    def clearTimeouts
      super

      clearPollTimeout
    end

    # doWrite to clear poll timeout
    #
    # @api private
    def doWrite
      clearPollTimeout
    end
    
    # Performs a write.
    #
    # @api private.
    def write(data, close)
      doWrite data
      @response.doEnd
      onClose
    end

    # Override end.
    #
    # @api private
    def doEnd
      clearPollTimeout
      super # return HTTPTransport.prototype.end.call(this);
    end
  end
end
