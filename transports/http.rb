module Transport
  class HTTPTransport < Transport::Transport

    def initialize mng, data, req
      super(mng, data, req)
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
          #self.onData(self.postEncoded ? qs.parse(buffer).d : buffer);
          onData(buffer)
        }

        if origin
          headers['Access-Control-Allow-Origin'] = '*'

          if req.headers.cookie 
            headers['Access-Control-Allow-Credentials'] = 'true'
          end
        end

        res.writeHead(200, headers)
        res.end('1')
      else
        @response = req.res
        super req
      end
    end

    def onData data
      Parser.decodePayload(data).each { | message |
        Logger.debug "#{@name} received data #{message}"
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
