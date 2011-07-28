module Transports

  class WebSocket < Tranports::Transport

    def initialize(msg, data, req)
      super(msg, data, req)
      @parser = Parser.new

      @parser.on :data { | packet |
        Logger.debug packet
        onMessage Parser.decodePacket(packet)
      }

      @parser.on :error { | x | doEnd }
      @parser.on :close { | x | doEnd }
    end

    def onSocketConnect
      @socket.setNoDelay true

      @buffer = true
      @buffered = []

      if @req[:headers][:upgrade] !== 'WebSocket'
        Logger.warn("#{@name} connection invalid")
        return doEnd
      end

      origin = @req[:headers][:origin]

      location = (@socket[:encrypted] ? 'wss' : 'ws') + '://' + @req[:headers][:host] + @req[:url]
      waitingForNonce = false

      if @req[:headers]['sec-web-socket-key1']
        # If we don't have the nonce yet, wait for it (HAProxy compatibility).
        if ! (@req[:head] and @req[:head]length >= 8)
          waitingForNonce = true
        end

        headers = [
          'HTTP/1.1 101 WebSocket Protocol Handshake',
          'Upgrade: WebSocket',
          'Connection: Upgrade',
          "Sec-WebSocket-Origin: #{origin}",
          "Sec-WebSocket-Location: #{location}"
        ]

        if @req[:headers]['sec-websocket-protocol']
          headers.push "Sec-WebSocket-Protocol: " + @req[:headers]['sec-websocket-protocol']
        end
      else
        headers = [
          'HTTP/1.1 101 Web Socket Protocol Handshake',
          'Upgrade: WebSocket',
          'Connection: Upgrade',
          "WebSocket-Origin: #{origin}",
          "WebSocket-Location: #{location}"
        ]
      end

      begin
        #TODO
        #@socket.write(headers.concat('', '').join('\r\n'));
        @socket.setTimeout 0
        @socket.setNoDelay true
        @socket.setEncoding 'utf8'
      rescue(ex)
        return doEnd
      end

      if waitingForNonce
        @socket.setEncoding 'binary'
      elsif proveReception headers
        flush
      end

      headBuffer = ''

      @socket.on 'data', { | data | 
        if waitingForNonce

          headBuffer << data

          return if headBuffer.length < 8

          # Restore the connection to utf8 encoding after receiving the nonce
          @socket.setEncoding 'utf8'

          waitingForNonce = false

          # Stuff the nonce into the location where it's expected to be
          @req[:head] = headBuffer[0..8]
          headBuffer = ''

          if proveReception headers
            flush
          end

          return
        end

        @parser.add data
      }
   end

    def write data
      if @open
        @drained = false

        if @buffer
          return @buffer.push data
        end


        #TODO

        #var length = Buffer.byteLength(data)
        #, buffer = new Buffer(2 + length);
        buffer.write('\u0000', 'binary');
        buffer.write(data, 1, 'utf8');
        buffer.write('\uffff', 1 + length, 'binary');

        begin 
          @drained = true if @socket.write buffer
        rescue
          doEnd
        end 

        Logger.debug("#{@name} writing", data)
      end
    end

    def flush
      @buffered.each { | data |
        write(data)
      }
    end

    def proveReception headers
      k1 = @req.headers['sec-websocket-key1']
      k2 = @req.headers['sec-websocket-key2']
     
      #TODO
=begin

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
      @socket.write(md5.digest('binary'), 'binary');
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
  for (var i = @i, chr, l = @buffer.length; i < l; i++){
    chr = @buffer[i];

    if (@buffer.length == 2 && @buffer[1] == '\u0000') 
      emit('close');
      @buffer = '';
      @i = 0;
      return;
    end

    if (i === 0)
      if (chr != '\u0000')
        doError('Bad framing. Expected null byte as first frame');
      else
        continue;
      end
    end

    if (chr == '\ufffd')
      emit('data', @buffer.substr(1, i - 1));
      @buffer = @buffer.substr(i + 1);
      @i = 0;
      return parse
    end 
  }
=end
      end

      def doError reason
        emit('error', reason)
      end
    end
  end
end
