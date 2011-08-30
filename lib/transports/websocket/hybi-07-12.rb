# socket.io-ruby
# Copyright(c) 2011 Oblong <chris@oblong.com>
# MIT Licensed
#
# Derived from
# socket.io-node
# Copyright(c) 2011 LearnBoost <dev@learnboost.com>
# MIT Licensed

# HTTP interface constructor. Interface compatible with all transports that
# depend on request-response cycles.
#
# @api public

module Transports
  module WebSocket
    class WebSocket < Transport::Transport

      # Inherits from Transport.
      def initialize(mng, data, req)
        # Transport name
        #
        # @api public
        @name = 'websocket'

        # parser
        @parser = Parser.new

        @parser.on('data') do | packet |
          onMessage(parser.decodePacket(packet))
        end

        @parser.on('ping')  do
          # version 8 ping => pong
          socket.write('\u008a\u0000')
        end

        @parser.on('close') do
          doEnd
        end

        @parser.on('error') do | reason |
          log.warn(name + ' parser error: ' + reason)
          doEnd
        end

        super
      end

      # Called when the socket connects.
      #
      # @api private
      def onSocketConnect 
        if (@req.headers.upgrade !== 'websocket')
          log.warn(@name + ' connection invalid')
          doEnd
          return
        end

        origin = @req.headers.origin
        location = (@socket.encrypted ? 'wss' : 'ws') + ':#' + @req.headers.host + @req.url

        if (!@req.headers['sec-websocket-key'])
          log.warn(@name + ' connection invalid: received no key')
          doEnd
          return
        end
          
        # calc key
        key = @req.headers['sec-websocket-key'];  
        shasum = crypto.createHash('sha1');  
        shasum.update(key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11");  
        key = shasum.digest('base64')

        headers = [
          'HTTP/1.1 101 Switching Protocols',
          'Upgrade: websocket',
          'Connection: Upgrade',
          'Sec-WebSocket-Accept: ' + key
        ]

        begin
          @socket.write(headers.concat('', '').join('\r\n'))
          @socket.setTimeout(0)
          @socket.setNoDelay(true)
        rescue
          doEnd
          return
        end

        @socket.on('data', def (data)
          @parser.add(data)
        end
      end


      # Writes to the socket.
      #
      # @api private
      def write data
        if @open
          buf = frame(0x81, data)
          @socket.write(buf, 'binary')
          log.debug(@name + ' writing', data)
        end
      end


      # Frame server-to-client output as a text packet.
      #
      # @api private
      def frame(opcode, str)
        dataBuffer = new Buffer(str)
        dataLength = dataBuffer.length
        startOffset = 2
        secondByte = dataLength

        if (dataLength > 65536)
          startOffset = 10
          secondByte = 127
        elsif (dataLength > 125)
          startOffset = 4
          secondByte = 126
        end

        outputBuffer = new Buffer(dataLength + startOffset)
        outputBuffer[0] = opcode
        outputBuffer[1] = secondByte
        dataBuffer.copy(outputBuffer, startOffset)

        case (secondByte)

          when 126
            outputBuffer[2] = dataLength >>> 8
            outputBuffer[3] = dataLength % 256

          when 127
            l = dataLength
            for (i = 1; i <= 8; ++i)
              outputBuffer[startOffset - i] = l & 0xff
              l >>>= 8
            end

        end

        return outputBuffer
      end

      # Closes the connection.
      #
      # @api private
      def doClose
        @socket.end
      end
    end


    # WebSocket parser
    #
    # @api public
    class Parser 

      include EventEmitter

      def initialize
        @state = {
          'activeFragmentedOperation' => nil,
          'lastFragment' => false,
          'masked' => false,
          'opcode' => 0
        }

        @overflow = nil
        @expectOffset = 0
        @expectBuffer = nil
        @expectHandler = nil
        @currentMessage = ''

        @opcodeHandlers = {
          # text
          '1' => lambda { | data |
            def finish(mask, data)
              @currentMessage += unmask(mask, data)

              if (@state.lastFragment)
                emit('data', @currentMessage)
                @currentMessage = ''
              end

              endPacket
            end

            def expectData (length)
              if (@state.masked)
                expect('Mask', 4) do | data |
                  mask = data
                  expect('Data', length) do | data |
                    finish(mask, data)
                  end
                end
              else
                expect('Data', length) do | data | 
                  finish(null, data)
                end
              end 
            end

             # decode length
            firstLength = data[1] & 0x7f
            if (firstLength < 126)
              expectData(firstLength)
            elsif (firstLength == 126) 

              expect('Length', 2) do | data |
                expectData(util.unpack(data))
              end

            elsif (firstLength == 127)
              expect('Length', 8) do | data |
                if (util.unpack(data.slice(0, 4)) != 0)
                  doError('packets with length spanning more than 32 bit is currently not supported')
                  return
                end

                lengthBytes = data.slice(4);  # note: cap to 32 bit length
                expectData(util.unpack(data))
              end
            end
          },

          # close
          '8' => lambda { | data |
            emit('close')
            reset
          },

          # ping
          '9' => lambda do | data |
            if (@state.lastFragment == false)
              doError('fragmented ping is not supported')
              return
            end
            
            def finish 
              emit('ping', unmask(mask, data))
              endPacket
            end

            def expectData
              if (@state.masked)
                expect('Mask', 4) do | data |
                  mask = data

                  expect('Data', length) do | data |
                    finish(mask, data)
                  end
                end
              else
                expect('Data', length) do  | data | 
                  finish(null, data)
                end
              end 
            end

             # decode length
            firstLength = data[1] & 0x7f

            if (firstLength == 0)
              finish(null, nil)
            elsif (firstLength < 126)
              expectData(firstLength)
            elsif (firstLength == 126)

              expect('Length', 2) do | data |
                expectData(util.unpack(data))
              end

            elsif (firstLength == 127)

              expect('Length', 8) do | data |
                expectData(util.unpack(data))
              end
            end
          end
        }

        @expect('Opcode', 2, processPacket);  
      end


      # Add new data to the parser.
      #
      # @api public
      def add data 
        if (@expectBuffer == nil)
          addToOverflow(data)
          return
        end

        toRead = Math.min(data.length, @expectBuffer.length - @expectOffset)
        data.copy(@expectBuffer, @expectOffset, 0, toRead)

        @expectOffset += toRead
        if (toRead < data.length)
           # at this point the overflow buffer shouldn't at all exist
          @overflow = new Buffer(data.length - toRead)
          data.copy(@overflow, 0, toRead, toRead + @overflow.length)
        end

        if (@expectOffset == @expectBuffer.length)
          bufferForHandler = @expectBuffer
          @expectBuffer = nil
          @expectOffset = 0
          @expectHandler.call(this, bufferForHandler)
        end
      end


      # Adds a piece of data to the overflow.
      #
      # @api private
      def addToOverflow data 
        if (@overflow == nil) 
          @overflow = data
        else
          prevOverflow = @overflow
          @overflow = new Buffer(@overflow.length + data.length)
          prevOverflow.copy(@overflow, 0)
          data.copy(@overflow, prevOverflow.length)
        end
      end


      # Waits for a certain amount of bytes to be available, then fires a callback.
      #
      # @api private
      def expect(what, length, handler)
        @expectBuffer = new Buffer(length)
        @expectOffset = 0
        @expectHandler = handler

        if (@overflow != nil)
          toOverflow = @overflow
          @overflow = nil
          add(toOverflow)
        end
      end

      # Start processing a new packet.
      #
      # @api private
      def processPacket(data)
        if ((data[0] & 0x70) != 0) 
          doError('reserved fields not empty')
        end

        @state.lastFragment = (data[0] & 0x80) == 0x80; 
        @state.masked = (data[1] & 0x80) == 0x80
        opcode = data[0] & 0xf

        if (opcode == 0)
           # continuation frame
          if (@state.opcode != 1 || @state.opcode != 2)
            doError('continuation frame cannot follow current opcode')
            return
          end
        end

        else 
          @state.opcode = opcode
        end

        @state.opcode = data[0] & 0xf
        handler = this.opcodeHandlers[@state.opcode]

        if (typeof handler == 'undefined') 
          doError('no handler for opcode ' + @state.opcode)
        else 
          handler(data)
        end
      end


      # Endprocessing a packet.
      #
      # @api private
      def endPacket
        @expectOffset = 0
        @expectBuffer = nil
        @expectHandler = nil

        if (@state.lastFragment && @state.opcode == @state.activeFragmentedOperation)
           # end current fragmented operation
          @state.activeFragmentedOperation = nil
        end

        @state.lastFragment = false
        @state.opcode = @state.activeFragmentedOperation != nil ? @state.activeFragmentedOperation : 0
        @state.masked = false
        @expect('Opcode', 2, processPacket);  
      end


      # Reset the parser state.
      #
      # @api private
      def reset
        @state = {
          'activeFragmentedOperation' => nil,
          'lastFragment' => false,
          'masked' => false,
          'opcode' => 0
        }

        @expectOffset = 0
        @expectBuffer = nil
        @expectHandler = nil
        @overflow = nil
        @currentMessage = ''
      end


      # Unmask received data.
      #
      # @api private
      def unmask(mask, buf)
        if (mask != nil)
          for (i = 0, ll = buf.length; i < ll; i++)
            buf[i] ^= mask[i % 4]
          }    
        end

        return buf != nil ? buf.toString('utf8') : ''
      end


      # Handles an error
      #
      # @api private
      def doError(reason)
        reset
        emit('error', reason)
        self
      end
  end
end
