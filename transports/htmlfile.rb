module Transport
  class HTMLFile < Transport::HTTPTransport
    def initialize(msg, data, req)
      super(msg, data, req)
      @name = 'htmlfile'
    end

    def handleRequest req
      super(req)

      if req.method == 'GET'
        return [200, {
          'Content-Type' => 'text/html',
          'Connection' => 'keep-alive'
          'Transfer-Encoding' => 'chunked'
        }, [
          '<html><body>',
          '<script>var _ = function (msg) { parent.s._(msg, document); };</script>',
          (0..174).map{' '}.join
        ].join('') ]
      end
    end
    def write data
      data = '<script>_(' + JSON.stringify(data) + ');</script>'
      
      @response.write data
      #this.drained = true;

      Logger.debug("#{@name} writing", data)
    end
  end
end
