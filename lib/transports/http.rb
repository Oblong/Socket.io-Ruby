# socket.io-ruby
# Copyright(c) 2011 Oblong <chris@oblong.com>
# MIT Licensed
#
# Derived from
# socket.io-node
# Copyright(c) 2011 LearnBoost <dev@learnboost.com>
# MIT Licensed

module Transport
  class HTTPTransport < Transport::Transport

    #rb only
    attr_accessor :postEncoded
    def initialize mng, data, req
      super

      #rb used by jsonp polling
      @postEncoded = false
    end

    def handleRequest req
      if req.method == 'POST'
        buffer = ''
        res = req.res
        origin = req.headers['origin']
        headers = { 'Content-Length' => 1 }

        req.on('data') { | data |
          buffer << data
        }

        req.on('end') do
          onData(@postEncoded ? CGI::parse(buffer)['d'] : buffer)
        end

        unless origin.nil?
          headers['Access-Control-Allow-Origin'] = '*'

          unless req.headers['cookie'].nil?
            headers['Access-Control-Allow-Credentials'] = 'true'
          end
        end

        res.writeHead 200, headers
        res.doEnd '1'
      else
        @response = req.res
        super
      end
    end

    def onData data
      Parser.decodePayload(data).each { | message |
        log.debug "#{@name} received data #{message}"
        onMessage message
      }
    end

    def doClose
      response.doEnd
    end

    def payload msgs
      write parser.encodePayload(msgs)
    end
  end
end
