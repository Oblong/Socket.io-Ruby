module Transport
  class XhrPolling < Transport::HttpPolling
    def setHeartbeatInterval; end
    def handleRequest; end
    def clearPollTimeout; end
    def clearTimeouts; end
    def doWrite; end
    def write; end
    def end; end
  end
end
