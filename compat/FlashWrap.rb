require 'flashpolicyd'
module PolicyServer
  class << self
    include EventEmitter

    attr_accessor port

    def initialize(options, origins){
      @policy = FlashPolicy.new 
      @origins = origins || ['*:*']
      @port = 843
      
      @options = options
      
      def createServer(socket)
        socket.on 'error', lambda { responder socket }
        responder socket
      end

      def serverError err
        # Special and common case error handling
        if err.errno == 13
          log(
            'Unable to listen to port `' + @port + '` as your Node.js instance does not have root privileges. ' +
            (
              @server
              ? 'The Flash Policy File requests will only be served inline over the supplied HTTP server. Inline serving is slower than a dedicated server instance.'
              : 'No fallback server supplied, we will be unable to answer Flash Policy File requests.'
            )
          )
          
          emit('connect_failed', err)
          @socket.removeAllListeners
          #delete me.socket
        else 
          log('FlashPolicyFileServer received an error event:\n' + (err.message ? err.message : err))
        end
      end

      def serverTimeout; end

      def serverClosed(err)
        
        if @server
          # Remove the inline policy listener if we close down
          # but only when the server was `online` (see listen prototype)
          if( @server['@'] && @server[online)
            @server.removeListener('connection', @server['@'])
          end
          
          # not online anymore
          @server.delete :online
        end
      end

      # create the net server
      @socket = net.createServer method(:createServer)

      # Listen for errors as the port might be blocked because we do not have root priv.
      @socket.on 'error', method(:serverError)


      @socket.on 'timeout', method(:serverTimeout)
      @socket.on 'close', method(:serverClosed)
      
      # Compile the initial `buffer`
      compile
    end

    #
    # Start listening for requests
    #
    # @param {Number} port The port number it should be listening to.
    # @param {Server} server A HTTP server instance, this will be used to listen for inline requests
    # @param {Function} cb The callback needs to be called once server is ready
    # @api public
    #
    def listen(port, server, cb)
      args = slice.call(arguments, 0)
      
      # assign the correct vars, for flexible arguments
      args.forEach(def args(arg){
        type = arg.class
        
        @port = arg if type == Fixnum
        callback = arg if type == Method
        @server = arg if type == Class
      })
      
      if (@server){
        
        # no one in their right mind would ever create a `@` prototype, so Im just gonna store
        # my def on the server, so I can remove it later again once the server(s) closes
        @server['@'] = def connection(socket){
          socket.once('data', def requestData(data){
            # if it's a Flash policy request, and we can write to the 
            if (
                 data
              && data[0] == 60
              && data.toString == '<policy-file-request/>\0'
              && socket
              && (socket.readyState == 'open' || socket.readyState == 'writeOnly')
            ){
              # send the buffer
              socket.end(me.buffer)
            end
          })
        end
        # attach it
        @server.on('connection', @server['@'])
      end
      
      # We add a callback method, so we can set a flag for when the server is `enabled` or `online`.
      # this flag is needed because if a error occurs and the we cannot boot up the server the
      # fallback functionality should not be removed during the `close` event
      @port >= 0 && @socket.listen(@port, def serverListening{
       me.socket.online = true
       if (callback) callback.call(me), callback = undefined
       
      })
      
      self
    end

    #
    # Responds to socket connects and writes the compile policy file.
    #
    # @param {net.Socket} socket The socket that needs to receive the message
    # @api private
    #
    def responder socket
      if (socket && socket.readyState == 'open' && socket.end)
        socket.end(@buffer)
      end
    end

    #
    # Compiles the supplied origins to a Flash Policy File format and stores it in a Node.js Buffer
    # this way it can be send over the wire without any performance loss.
    #
    # @api private
    #
    def compile

      xml = [
        '<?xml version="1.0"?>',
        '<!DOCTYPE cross-domain-policy SYSTEM "http:#www.macromedia.com/xml/dtds/cross-domain-policy.dtd">',
        '<cross-domain-policy>'
      ]
      
      # add the allow access element
      @origins.each { | origin | 
        parts = origin.split(':')
        xml << '<allow-access-from domain="' + parts[0] + '" to-ports="'+ parts[1] +'"/>'
      }
      
      xml << '</cross-domain-policy>'
      
      # store the result in a buffer so we don't have to re-generate it all the time
      
    end

    #
    # Adds a new origin to the Flash Policy File.
    #
    # @param {Arguments} The origins that need to be added.
    # @api public
    #
    def add(*args)
      i = args.length
      
      # flag duplicates
      while (i--)
        if @origins.index(args[i]) >= 0
          args[i] = null
        end
      end
      
      # Add all the arguments to the array
      # but first we want to remove all `falsy` values from the args
      @origins << args.select { | value | value }
      compile
    end

    #
    # Removes a origin from the Flash Policy File.
    #
    # @param {String} origin The origin that needs to be removed from the server
    # @api public
    #
    def remove origin
      position = @origins.index origin
      
      # only remove and recompile if we have a match
      if position > 0
        @origins.splice!(position,1)
        compile
      end
    end

    #
    # Closes and cleans up the server
    #
    # @api public
    #
    def close
      @socket.removeAllListeners
      @socket.close
    end

    #
    # Creates a new server instance.
    #
    # @param {Object} options A options object to override the default config
    # @param {Array} origins The origins that should be allowed by the server
    # @api public
    #
    def createServer(options, origins)
      origins = origins.class == Array ? origins : (options.class == Array ? options : false)
      options = !(options.class == Array) && options ? options : {end
      
      Server.new options, origins
    end

  end
end
