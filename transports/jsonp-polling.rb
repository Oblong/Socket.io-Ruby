module Transport
  class JsonpPolling < Transport::HttpPolling

    def initialize(msg, data, req)
      super(msg, data, req)
      @name = 'jsonppolling'
      @postEncoded = true
    end

    def doWrite data

      super(data)
      data = JSON.encode(data) unless data.kind_of? String

      @socket.emit data
    end
  end
end
