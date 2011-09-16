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
  class HTTPTransport < Transports::Base

    #rb only
    attr_accessor :postEncoded
    def initialize mng, data, req
      super

      #rb used by jsonp polling
      @postEncoded = false
    end

		# Handles a request.
		#
		# @api private
    def handleRequest req
      if req.method == 'POST'
        buffer = ''
        res = req.res
        origin = req.headers['origin']
        headers = { 'Content-Length' => 1 }

        req.on('data') do | data |
          buffer << data
        end 

        req.on('end') do
          res.writeHead(200, headers)
          res.doEnd('1')

          onData(@postEncoded ? CGI::parse(buffer)['d'] : buffer)
        end

        unless origin.nil?
          headers['Access-Control-Allow-Origin'] = '*'

          unless req.headers['cookie'].nil?
            headers['Access-Control-Allow-Credentials'] = 'true'
          end
        end
      else
        @response = req.res
        super
      end
    end

		# Handles data payload.
		#
		# @api private
    def onData data
      log.debug(@name, 'received data', data)

      Parser.decodePayload(data).each do | message |
        onMessage message
      end
    end

		# Closes the request-response cycle
		#
		# @api private
    def doClose
      @response.doEnd
    end

		# Writes a payload of messages
		#
		# @api private
    def payload msgs
      write Parser::encodePayload(msgs)
    end
  end
end
