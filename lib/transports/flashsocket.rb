# socket.io-ruby
# Copyright(c) 2011 Oblong <chris@oblong.com>
# MIT Licensed
#
# Derived from
# socket.io-node
# Copyright(c) 2011 LearnBoost <dev@learnboost.com>
# MIT Licensed

require 'compat/FlashWrap'
module Transports
  module FlashSocket

    class << self
      include Transports::WebSocket
      def initialize(mng, data, req)
        @name = 'flashsocket'
        super
      end
    end

    def init manager
      @manager = manager

      def create
        @server = $POLICY_SERVER

        @server.on('close') do
          @server = nil
        end

        @server.listen(manager.get('flash policy port')) do
          manager.server.call
        end

        @manager.flashPolicyServer = @server
      end

      # listen for origin changes, so we can update the server
      @manager.on('set:origins') do |value, key|
        if @server.nil?
          return
        end

        # update the origins and compile a new response buffer
        # TODO
        #@server.origins = (value.class == Array) ? value : [value]
        #@server.compile
      end

      # destory the server and create a new server
      @manager.on('set:flash policy port') do |value, key|
        transports = @manager.get('transports')

        if @server.port != value && transports.index('flashsocket')
          # destroy the server and rebuild it on a new port
          # TODO
          #@server.close
          create
        end
      end

      # only start the server
      @manager.on('set:transports') do | value, key |
        if (!@server && @manager.get('transports').index('flashsocket')) 
          create
        end 
      end

      # check if we need to initialize at start
      if @manager.get('transports').index('flashsocket')
        create
      end 
    end
  end
end
