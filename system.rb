require 'rubygems'
require 'rack'
require 'cgi'
require 'uuid'

base = File.dirname(__FILE__)
$:.unshift base

require 'parser'
require 'params'

UUID.state_file = false

module Socket
  def self.emit content
    [ 200, {
      'Content-Type' => 'text/plain; charset=UTF-8',
      'Content-Length' => content.length.to_s,
      'Connection' => 'Keep-Alive'
    }, content ]
  end

  class Socket
    def initialize app; end


    def call env
      parts = request['PATH_INFO'].split('/')
      channel = parts[0]
      if parts.length > 1
        method = parts[1]
      else 
        message = Emitter.handshake
      end

      emit message
    end
  end
end
