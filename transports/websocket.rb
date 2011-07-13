module Transports

  class WebSocket < Tranports::Transport

    def initialize
      @parser = Parser.new

      @parser.on :data { | packet |
        Logger.debug packet
        onMessage Parser.decodePacket(packet)
      }

      @parser.on :error { | x | end }
      @parser.on :close { | x | end }

=begin
  Transport.call(this, mng, data, req);
=end
    end

    def onSocketConnect
=begin
  var self = this;

  this.socket.setNoDelay(true);

  this.buffer = true;
  this.buffered = [];

  if (this.req.headers.upgrade !== 'WebSocket') {
    this.log.warn(this.name + ' connection invalid');
    this.end();
    return;
  }

  var origin = this.req.headers.origin
    , location = (this.socket.encrypted ? 'wss' : 'ws')
               + '://' + this.req.headers.host + this.req.url
    , waitingForNonce = false;

  if (this.req.headers['sec-websocket-key1']) {
    // If we don't have the nonce yet, wait for it (HAProxy compatibility).
    if (! (this.req.head && this.req.head.length >= 8)) {
      waitingForNonce = true;
    }

    var headers = [
        'HTTP/1.1 101 WebSocket Protocol Handshake'
      , 'Upgrade: WebSocket'
      , 'Connection: Upgrade'
      , 'Sec-WebSocket-Origin: ' + origin
      , 'Sec-WebSocket-Location: ' + location
    ];

    if (this.req.headers['sec-websocket-protocol']){
      headers.push('Sec-WebSocket-Protocol: '
          + this.req.headers['sec-websocket-protocol']);
    }
  } else {
    var headers = [
        'HTTP/1.1 101 Web Socket Protocol Handshake'
      , 'Upgrade: WebSocket'
      , 'Connection: Upgrade'
      , 'WebSocket-Origin: ' + origin
      , 'WebSocket-Location: ' + location
    ];
  }

  try {
    this.socket.write(headers.concat('', '').join('\r\n'));
    this.socket.setTimeout(0);
    this.socket.setNoDelay(true);
    this.socket.setEncoding('utf8');
  } catch (e) {
    this.end();
    return;
  }

  if (waitingForNonce) {
    this.socket.setEncoding('binary');
  } else if (this.proveReception(headers)) {
    self.flush();
  }

  var headBuffer = '';

  this.socket.on('data', function (data) {
    if (waitingForNonce) {
      headBuffer += data;

      if (headBuffer.length < 8) {
        return;
      }

      // Restore the connection to utf8 encoding after receiving the nonce
      self.socket.setEncoding('utf8');
      waitingForNonce = false;

      // Stuff the nonce into the location where it's expected to be
      self.req.head = headBuffer.substr(0, 8);
      headBuffer = '';

      if (self.proveReception(headers)) {
        self.flush();
      }

      return;
    }

    self.parser.add(data);
  });
=end
    end

    def write data
=begin
  if (this.open) {
    this.drained = false;

    if (this.buffer) {
      this.buffered.push(data);
      return this;
    }

    var length = Buffer.byteLength(data)
      , buffer = new Buffer(2 + length);

    buffer.write('\u0000', 'binary');
    buffer.write(data, 1, 'utf8');
    buffer.write('\uffff', 1 + length, 'binary');

    try {
      if (this.socket.write(buffer)) {
        this.drained = true;
      }
    } catch (e) {
      this.end();
    }

    this.log.debug(this.name + ' writing', data);
  }
=end
    end

    def flush
      @buffered.each { | data |
        write(data)
      }
    end

    def proveReception headers
=begin
  var self = this
    , k1 = this.req.headers['sec-websocket-key1']
    , k2 = this.req.headers['sec-websocket-key2'];

  if (k1 && k2){
    var md5 = crypto.createHash('md5');

    [k1, k2].forEach(function (k) {
      var n = parseInt(k.replace(/[^\d]/g, ''))
        , spaces = k.replace(/[^ ]/g, '').length;

      if (spaces === 0 || n % spaces !== 0){
        self.log.warn('Invalid ' + self.name + ' key: "' + k + '".');
        self.end();
        return false;
      }

      n /= spaces;

      md5.update(String.fromCharCode(
        n >> 24 & 0xFF,
        n >> 16 & 0xFF,
        n >> 8  & 0xFF,
        n       & 0xFF));
    });

    md5.update(this.req.head.toString('binary'));

    try {
      this.socket.write(md5.digest('binary'), 'binary');
    } catch (e) {
      this.end();
    }
  }

  return true;
=end
    end

    def payload messageList
      messageList.each { | message |
        write(message)
      }
    end

    def doClose
      @socket.doEnd
    end

  end

  module WebSocket
    class Parser
      attr_accessor :buffer

      def initialize
        @buffer = ''
        @i = 0
      end

      def add data
        buffer += data
        parse
      end

      def parse
=begin
  for (var i = this.i, chr, l = this.buffer.length; i < l; i++){
    chr = this.buffer[i];

    if (this.buffer.length == 2 && this.buffer[1] == '\u0000') {
      this.emit('close');
      this.buffer = '';
      this.i = 0;
      return;
    }

    if (i === 0){
      if (chr != '\u0000')
        this.error('Bad framing. Expected null byte as first frame');
      else
        continue;
    }

    if (chr == '\ufffd'){
      this.emit('data', this.buffer.substr(1, i - 1));
      this.buffer = this.buffer.substr(i + 1);
      this.i = 0;
      return this.parse();
    }
  }
=end
      end

      def doError reason
        emit('error', reason)
      end
    end
  end
end
