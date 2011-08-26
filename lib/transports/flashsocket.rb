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
        super
        @name = 'flashsocket'
      end
    end

    def init manager

      def create
        # TODO
        @server = require('policyfile').createServer({ 
          :log => lambda { | msg |
            manager.log.info(msg)
          }
        }, manager.get('origins'))

        @server.on('close') { | x | server = nil })

        @server.listen(manager.get('flash policy port'), manager.server);

        manager.flashPolicyServer = @server
      end

      # listen for origin changes, so we can update the server
      manager.on('set:origins') { |value, key|
        if @server.nil?
          return
        end

        # update the origins and compile a new response buffer
        @server.origins = (value.class == Array) ? value : [value]
        @server.compile
      }

      # destory the server and create a new server
      manager.on('set:flash policy port') { |value, key|
        transports = manager.get 'transports'

        if @server.port != value && transports.index('flashsocket')
          # destroy the server and rebuild it on a new port
          @server.close
          create
        end
      }

      # only start the server
      manager.on('set:transports') { | value, key |
        if (!@server && manager.get('transports').index('flashsocket')) 
          create
        end 
      }

      # check if we need to initialize at start
      if manager.get('transports').index('flashsocket')
        create
      end 
    end
  end
end
