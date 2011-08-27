# socket.io-ruby
# Copyright(c) 2011 Oblong <chris@oblong.com>
# MIT Licensed
#
# Derived from
# socket.io-node
# Copyright(c) 2011 LearnBoost <dev@learnboost.com>
# MIT Licensed

module Transports
  # Inherits from Transport.
  class XhrPolling < Transports::HttpPolling

    # Ajax polling transport.
    # 
    # @api public
    def initialize(mng, data, req)
      super

      # Transport name
      #
      # @api public
      @name = 'xhr-polling'
    end

    # Frames data prior to write.
    # 
    # @api private
    def doWrite data
      super

      origin = @req.headers['origin']

      headers = {
        'Content-Type' => 'text/plain; charset=UTF-8',
        'Content-Length' => data.nil? ? 0 : data.length,
        'Connection' => 'Keep-Alive'
      }

      unless origin.nil?
        # https://developer.mozilla.org/En/HTTP_Access_Control
        headers['Access-Control-Allow-Origin'] = '*'

        unless @req.headers['cookie'].nil?
          headers['Access-Control-Allow-Credentials'] = 'true'
        end
      end

      @response.writeHead 200, headers
      @response.write data

      log.debug(@name + ' writing', data);
    end
  end
end
