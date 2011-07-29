#TODO
#, qs = require('querystring');

module Transport
  class HTTPTransport < Transport::Transport

    #rb
    attr_accessor @postEncoded
    def initialize mng, data, req
      super

      #rb used by jsonp polling
      @postEncoded = false
    end

    def handleRequest req
      if req.method == 'POST'
        buffer = ''
        res = req.res
        origin = req.headers.origin
        headers = { 'Content-Length' => 1 }

        req.on 'data' { | data |
          buffer << data
        }

        req.on 'end' { | x |
          #TODO
          onData(@postEncoded ? qs.parse(buffer).d : buffer)
        }

        if origin
          headers['Access-Control-Allow-Origin'] = '*'

          if req.headers.cookie 
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
      response.end
    end

    def payload msgs
      write parser.encodePayload(msgs)
    end
  end
end
