module Transport
  class HTMLFile < Transport::HTTPTransport
    def initialize(msg, data, req)
      super(msg, data, req)
      @name = 'htmlfile'
    end

    def handleRequest &req
      super(req)

      if req.method == 'GET'
        req.response = {
          :status => 200,
          :header => {
            'Content-Type' => 'text/html',
            'Connection' => 'keep-alive'
            'Transfer-Encoding' => 'chunked'
          }, 
          :body => [
            '<html><body>',
            '<script>var _ = function (msg) { parent.s._(msg, document); };</script>',
            (0..174).map{' '}.join
          ]
        }
      end
    end

    def write data
      data = '<script>_(' + JSON.stringify(data) + ');</script>'
      
      @response.write data
      @drained = true;

      Logger.debug("#{@name} writing", data)
    end
  end
end
