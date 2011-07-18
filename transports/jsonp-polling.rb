module Transport
  class JsonpPolling < Transport::HttpPolling

    def initialize(msg, data, req)
      super(msg, data, req)
      @name = 'jsonppolling'
      @postEncoded = true
      @head = 'io.j[0]('
      @foot = ');'

=begin
  if (data.query.i) {
    this.head = 'io.j[' + data.query.i + '](';
  }
=end
    end

    def doWrite data
      super(data)
=begin
  var data = data === undefined
      ? '' : this.head + JSON.stringify(data) + this.foot;
=end
      data = JSON.encode(data) unless data.kind_of? String

      @socket.emit data
#  this.log.debug(this.name + ' writing', data);
    end
  end
end
