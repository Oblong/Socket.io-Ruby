# socket.io-ruby
# Copyright(c) 2011 Oblong <chris@oblong.com>
# MIT Licensed
#
# Derived from
# socket.io-node
# Copyright(c) 2011 LearnBoost <dev@learnboost.com>
# MIT Licensed

module Parser
  @regexp = /([^:]+):([0-9]+)?(\+)?:([^:]+)?:?([\s\S]*)?/

  @@packet = [ 
    'disconnect', 'connect', 'heartbeat', 'message',
    'json',       'event',   'ack',       'error', 
    'noop'
  ]

  @@reasons = [ 'transport not supported' , 'client not handshaken' , 'unauthorized' ]
  @@advice = [ 'reconnect' ]

  class << self
    def initialize; end
    include EventEmitter
  end

  def self.encodePacket packet
    type = @@packet.index(packet[:type])
    id = packet[:id] || ''
    endpoint = packet[:endpoint] ||  ''
    ack = packet[:ack]
    data = nil

    case packet[:type]
      when 'error'
        reason = packet[:reason] ? @@reasons.index(packet[:reason]) : ''
        adv = packet[:advice] ? @@advice.index(packet[:advice]) : ''

        if reason 
          reason = @@reasons[reason]
        end

        if adv
          adv = @@advice[adv]
        end

        if (reason != '' || adv != '')
          data = reason + (adv != '' ? ('+' + adv) : '')
        end

      when 'message'
        if (packet.data != '')
          data = packet.data
        end

      when 'event'
        ev = { 'name' => packet.name }

        if (packet.args && packet.args.length) 
          ev.args = packet.args
        end 

        data = JSON.encode(ev)

      when 'json'
        data = JSON.encode packet.data

      when 'connect'
        if (packet.qs)
          data = packet.qs
        end
        
      when 'ack'
        data = packet.ackId + (packet.args && packet.args.length ? '+' + JSON.encode(packet.args) : '')
    end

    # construct packet with required fragments
    encoded = [
      type,
      id + (ack == 'data' ? '+' : ''),
      endpoint
    ]

    # data fragment is optional
    encoded << data unless data.nil?

    encoded.join(':')
  end

  # Encodes multiple messages (payload).
  #
  # @param {Array} messages
  # @api private
  def encodePayload packets
    decoded = ''

    return packets[0] if packets.length == 1

    packets.each do | packet, i |
      decoded << '\ufffd' + packet.length + '\ufffd' + packets[i]
    end

    decoded
  end


  # Decodes a packet
  # 
  # @api private
  def decodePacket data
    array = data.match(@regexp)

    return {} if pieces.nil?

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

    packet
  end

  # Decodes data payload. Detects multiple messages
  # 
  # @return [Array] messages
  # @api public
  def decodePayload data
    if data[0] == '\ufffd'
      ret = []

      data[1..-1].split('\ufffd').each { | payload |
        ret << decodePacket(payload)
      }

      ret
    else 
      [Parser::decodePacket data]
    end
  end
end
