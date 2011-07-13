module Transport
  class HTMLFile < Transport::HTTPTransport
    def initialize(msg, data, req)
      super(msg, data, req)
      @name = 'htmlfile'
    end

    def handleRequest req
      super(req)
=begin
  if (req.method == 'GET') {
    req.res.writeHead(200, {
        'Content-Type': 'text/html'
      , 'Connection': 'keep-alive'
      , 'Transfer-Encoding': 'chunked'
    });

    req.res.write(
        '<html><body>'
      + '<script>var _ = function (msg) { parent.s._(msg, document); };</script>'
      + new Array(174).join(' ')
    );
  }
=end
    def write data
      data = '<script>_(' + JSON.stringify(data) + ');</script>';
      
      @response.write data

      Logger.debug("#{@name} writing", data)
    end
  end
end
