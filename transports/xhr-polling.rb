module Transport
  class XhrPolling < Transport::HttpPolling
    def initialize(msg, data, req)
      super(msg, data, req)
      @name = 'xhr-polling'
    end

    def doWrite data
      super(data)

      origin = @req.headers['origin']

      headers = {
        'Content-Type' => 'text/plain; charset=UTF-8',
        'Content-Length' => data.nil? 0 : data.length,
        'Connection' => 'Keep-Alive'
      }


      if (origin) 
        # https://developer.mozilla.org/En/HTTP_Access_Control
        headers['Access-Control-Allow-Origin'] = '*';

        unless @req.headers['cookie'].nil?
          headers['Access-Control-Allow-Credentials'] = 'true'
        end
      end

      [200, headers, data]
    end
  end
end
