module Transport
  class JsonpPolling < Transport::HttpPolling
    def initialize
      @socket = Socket.new
    end

    def setHeartbeatInterval; end
    def handleRequest; end
    def clearPollTimeout; end
    def clearTimeouts; end
    def doWrite data

      super(data)
      data = JSON.encode(data) unless data.kind_of? String

      @socket.emit data
    end

    def write; end
    def end; end
  end
end
