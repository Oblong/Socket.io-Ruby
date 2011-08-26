# socket.io-ruby
# Copyright(c) 2011 Oblong <chris@oblong.com>
# MIT Licensed
#
# Derived from
# socket.io-node
# Copyright(c) 2011 LearnBoost <dev@learnboost.com>
# MIT Licensed

module Transports
  class HTMLFile < Transports::HTTPTransport
    def initialize msg, data, req
      super
      @name = 'htmlfile'
    end

    def handleRequest req
      super

      if req.method == 'GET'
        req.response = {
          'status' => 200,
          'header' => {
            'Content-Type' => 'text/html',
            'Connection' => 'keep-alive',
            'Transfer-Encoding' => 'chunked'
          }, 
          'body' => [
            '<html><body>',
            '<script>var _ = function (msg) { parent.s._(msg, document); };</script>',
            (0..174).map{' '}.join
          ].join('')
        }
      end
    end

    def write data
      data = '<script>_(' + JSON.generate(data) + ');</script>'
      
      @response.write data
      @drained = true

      log.debug "#{@name} writing", data
    end
  end
end
