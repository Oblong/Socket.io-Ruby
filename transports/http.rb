module Transport
  class HTTPTransport < Transport::Transport
    attr_accessor :name

    def handleRequest req
      if req.method == 'POST'
        buffer = ''
        res = req.res
        origin = req.headers.origin
        headers = { 'Content-Length' => 1 }

        req.on 'data' { | data |
          buffer += data
        }

        req.on 'end' { | x |
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
      end
=begin
    } else {
      this.response = req.res;

      Transport.prototype.handleRequest.call(this, req);
    }
=end
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
      write(parser.encodePayload(msgs))
    end
  end
end
