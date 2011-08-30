# socket.io-ruby
# Copyright(c) 2011 Oblong <chris@oblong.com>
# MIT Licensed
#
# Derived from
# socket.io-node
# Copyright(c) 2011 LearnBoost <dev@learnboost.com>
# MIT Licensed
#



# HTTP interface constructor. Interface compatible with all transports that
# depend on request-response cycles.
#
# @api public
module Transports

  module WebSocket
    # Inherits from Transport.
    class << self < Transports::Base

      def initialize(msg, data, req)
        # Transport name
        #
        # @api public
        @name = 'websocket'

        @parser = Parser.new

        @parser.on('data') { | packet |
          log.debug(@name + ' received data packet', packet)

          # rb NOTE: I Don't know how this would actually work...
          onMessage Parser::decodePacket(packet)
          # js:
          # self.onMessage(parser.decodePacket(packet))
        }

        @parser.on('close') do
          doEnd 
        end

        @parser.on('error') do
          doEnd
        end

        super
      end


      # Called when the socket connects.
      #
      # @api private
      #

      def onSocketConnect
        @socket.setNoDelay(true)

        @buffer = true
        @buffered = []

        if @req.headers[:upgrade] != 'WebSocket'
          log.warn @name + ' connection invalid'
          doEnd
          return
        end

        origin = @req.headers[:origin]

        location = (@socket[:encrypted] ? 'wss' : 'ws') + '://' + @req[:headers][:host] + @req[:url]
        waitingForNonce = false

        if @req.headers['sec-web-socket-key1']
          # If we don't have the nonce yet, wait for it (HAProxy compatibility).
          if ! (@req[:head] and @req[:head].length >= 8)
            waitingForNonce = true
          end

          headers = [
            'HTTP/1.1 101 WebSocket Protocol Handshake',
            'Upgrade: WebSocket',
            'Connection: Upgrade',
            "Sec-WebSocket-Origin: #{origin}",
            "Sec-WebSocket-Location: #{location}"
          ]

          if @req.headers['sec-websocket-protocol']
            headers.push "Sec-WebSocket-Protocol: " + @req.headers['sec-websocket-protocol']
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
          @socket.write(headers.concat(['', '']).join("\r\n"))
          @socket.setTimeout 0
          @socket.setNoDelay true
          @socket.setEncoding 'utf8'
        rescue
          return doEnd
        end

        if waitingForNonce
          @socket.setEncoding 'binary'
        elsif proveReception headers
          flush
        end

        headBuffer = ''

        @socket.on('data') do | data | 
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
        end
      end


      # Writes to the socket.
      #
      # @api private
      def write(data) 
        if @open
          @drained = false

          if @buffer
            @buffer.push data
            return self
          end

          length = Buffer.byteLength(data)
            , buffer = new Buffer(2 + length)

          buffer = [0, 0, data, 0xff, 0xff].flatten.pack('c*')

          begin 
            @drained = true if @socket.write buffer
          rescue
            doEnd
          end 

          log.debug(@name + ' writing', data)
        end
      end


      # Flushes the internal buffer
      #
      # @api private
      def flush() 
        @buffered.each do | data |
          write(data)
        end 
      end

      # Finishes the handshake.
      #
      # @api private
      def proveReception headers
        k1 = @req.headers['sec-websocket-key1']
        k2 = @req.headers['sec-websocket-key2']
       
        if k1 and k2
          md5 = Digest::MD5.new

          [k1, k2].each do | k |
            n = k.gsub(/[^\d]/, '').to_i
            spaces = k.gsub(/[^ ]/, '').length

            if spaces == 0 or n % spaces != 0
              log.warn('Invalid ' + name + ' key: "' + k + '".')
              doEnd
              return false
            end

            n /= spaces

            md5.update([
              n >> 24 & 0xFF,
              n >> 16 & 0xFF,
              n >> 8  & 0xFF,
              n       & 0xFF].pack('c*'))
          end

          md5.update(@req[:head])

          begin
            @socket.write(md5.digest('binary'), 'binary')
          rescue
            doEnd
          end
        end

        true
      end


      # Writes a payload.
      #
      # @api private
      def payload(msgs) 
        messageList.each { | message |
          write(message)
        }
      end


      # Closes the connection.
      #
      # @api private
      def doClose 
        @socket.doEnd
      end

    end

    class Parser
      attr_accessor :buffer

      # WebSocket parser
      #
      # @api public
      def initialize
        @buffer = ''
        @i = 0
      end

      # Inherits from EventEmitter.
      include EventEmitter

      # Adds data to the buffer.
      #
      # @api public
      def add data
        @buffer << data
        parse
      end

      # Parses the buffer.
      # 
      # @api private
      def parse
        (@i..@buffer.length).each do | i |
          #rb 1.8 support
          chr = @buffer[i..i+1].unpack('s')

          if @buffer.length == 2 && @buffer.unpack('s')[1] == 0
            emit 'close'
            @buffer = ''
            @i = 0
            return
          end
          
          if i == 0
            if chr != 0
              doError 'Bad framing. Expected null byte as first frame'
            else
              next
            end
          end

          if chr == 0xfffd
            emit('data', @buffer[1..@i - 1])
            @buffer = @buffer[@i + 1..-1]
            @i = 0;
            return parse
          end
        end 
      end

      # Handles an error
      # 
      # @api private
      def doError reason
        @buffer = 0
        @i = 0
        emit 'error', reason
        self
      end
    end
  end
end
