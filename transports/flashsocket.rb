module Transports
  class FlashSocket < Transports::WebSocket
    def initialize(mng, data, req)
      super
      @name = 'flashsocket'
    end

    def init manager

      def create
        # TODO
        server = require('policyfile').createServer({ 
          log: function(msg){
            manager.log.info(msg.toLowerCase());
          }
        }, manager.get('origins'))

        @server.on('close', lambda { | x | server = nil })

        @server.listen(manager.get('flash policy port'), manager.server);

        manager.flashPolicyServer = server
      end

      # listen for origin changes, so we can update the server
      manager.on 'set:origins', lambda { |value, key|
        if !server 
          return
        end

        # update the origins and compile a new response buffer
        server.origins = (value.class == Array) ? value : [value]
        #server.compile
      }

      # destory the server and create a new server
      manager.on 'set:flash policy port', lambda { |value, key|
        transports = manager.get 'transports'

        if (server && server.port != value && transports.index('flashsocket')) 
          # destroy the server and rebuild it on a new port
          server.close
          create
        end
      }

      # only start the server
      manager.on 'set:transports', lambda { | value, key |
        if (!server && manager.get('transports').index('flashsocket')) 
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
