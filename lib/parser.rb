# snagged from socket.io-node tag v0.7.6
# core parts intact, converted to ruby-style

module Parser
  @regexp = /^([^:]+):([0-9]+)?(\+)?:([^:]+)?:?(.*)?$/

  @tk = {
    :packet => [ 
      'disconnect', 'connect', 'heartbeat', 'message',
      'json',       'event',   'ack',       'error', 
      'noop'
    ],
    :reasons => [ 'transport not supported' , 'client not handshaken' , 'unauthorized' ],
    :advice => [ 'reconnect' ]
  }

  def self.decodePayload data
    if data[0] == '\ufffd'
      ret = []

      data.split('\ufffd').each { | payload |
        ret.push(Parser.decodePacket payload)
      }

      ret
    else 
      [Parser.decodePacket data]
    end
  end

  def self.decodePacket data
    array = data.match(@regexp)

    return {} if pieces.is_nil?

    id = array[2] || ''
    data = array[5] || ''

    packet = {
      :type => @tk[:packet][array[1]],
      :endpoint => array[4] || ''
    }

    # whether we need to acknowledge the packet
    if id 
      packet[:id] = id

      if array[3]
        packet[:ack] = 'data'
      else
        packet[:ack] = true
      end
    end

    # handle different packet types
    case packet[:type]
    when 'error'
      splitup = data.split('+')
      packet[:reason] = @tk[:reasons][splitup[0]] || ''
      packet[:advice] = @tk[:advice][splitup[1]] || ''

    when 'message'
      packet[:data] = data || ''

    when 'event'
      begin
        opts = JSON.parse(data)
        packet[:name] = opts.name
        packet[:args] = opts.args
      rescue; end

      packet[:args] = packet[:args] || []

    when 'json'
      begin
        packet[:data] = JSON.parse(data)
      rescue; end

    when 'connect'
      packet[:qs] = data || ''

    when 'ack'
      array = data.match(/^([0-9]+)(\+)?(.*)/)

      if array
        packet[:ackId] = array[1]
        packet[:args] = []

        if array[3]
          begin
            packet[:args] = array[3] ? JSON.parse(array[3]) : []
          rescue; end
        end
      end
    end

    return packet
  end
end
