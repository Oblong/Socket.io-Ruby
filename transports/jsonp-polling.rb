module Transport
  class JsonpPolling < Transport::HttpPolling

    def initialize(msg, data, req)
      #rb make sure this stays at the top because
      #   the postEncoded assignment here would 
      #   otherwise be overridden
      super

      @name = 'jsonppolling'
      @postEncoded = true
      @head = 'io.j[0]('
      @foot = ');'
      @head = 'io.j[' + data.query.i + '](' if data[:query][:i]
    end

    def doWrite data
      super

      if data.nil?
        data = ''
      else
        data = @head + JSON.generate(data) + @foot
      end

      data = JSON.generate(data) unless data.kind_of? String

      @socket.emit data
      log.debug @name + ' writing', data
    end
  end
end
