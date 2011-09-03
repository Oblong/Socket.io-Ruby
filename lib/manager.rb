# socket.io-ruby
# Copyright(c) 2011 Oblong <chris@oblong.com>
# MIT Licensed
#
# Derived from
# socket.io-node
# Copyright(c) 2011 LearnBoost <dev@learnboost.com>
# MIT Licensed

# rb only
$protocol = 1

# Manager constructor.
#
# @param [HTTPServer] server
# @param [Object] options, optional
# @api public
class Manager

  attr_accessor :rooms
  attr_accessor :static

  # rb only {
  #  Notes: We really can't include the client side
  #  JS and parse it, so we have to fake it here.
  #  
  #  This is ok since we aren't using much data from it anyway
  attr_reader :client
  @@client = {
    :version => '0.8.2'
  }
  # }

  def initialize(server, options = nil)
    # rb only
    @funMap = {}

    @server = server
    @namespaces = {}
    @sockets = of('')

    @settings = {
      'origins' => '*:*',
      'log' => true,
      'store' => Disk.new,
      'logger' => SocketIO::Logger.new,
      'heartbeats' => true,
      'resource' => '/socket.io',

      # rb only :: this is a map between what the client side is 
      # trying to find and the crippled limitationg of Ruby's 
      # naming convention
      'transports' => { 
        'WebSocket' => 'websocket', 
        'HTMLFile' => 'htmlfile',
        'XhrPolling' => 'xhr-polling',
        'JsonpPolling' => 'jsonp-polling'
      },
      'authorization' => false,
      'log level' => 3,
      'close timeout' => 25,
      'heartbeat timeout' => 15,
      'heartbeat interval' => 20,
      'polling duration' => 20,
      'flash policy server' => true,
      'flash policy port' => 843,
      'destroy upgrade' => true,
      'browser client' => true,
      'browser client minification' => false,
      'browser client etag' => false,
      'browser client handler' => false,
      'client store expiration' => 15
    }

    @settings.merge!(options) unless options.nil?

    initStore

    @oldListeners = server.listeners('request')
    server.removeAllListeners 'request'

    server.on('request') do |req, res|
      handleRequest req, res
    end

    server.on('upgrade') do |req, socket, head|
      handleUpgrade(req, socket, head)
    end 

=begin
    server.on('close') { | x |
      clearInterval(self.gc)
    }

=end
    @settings['transports'].each_key { | trans | 
      if eval("Transports::#{trans}").class == Module 
        if eval("Transports::#{trans}").respond_to? :init
          eval("Transports::#{trans}").init self
        end
      end
    }

    log.info('socket.io started')
    
    #rb: only
    doStatic
  end

  # store accessor shortcut.
  # 
  # @api public
  def store; get 'store'; end

  # Logger accessor.
  #
  # @api public
  def log
    return nil if disabled :log
    logger = get 'logger'
    logger.level = get 'log level'
    logger
  end

  # Get settings.
  # 
  # @api public
  def get key 
    @settings[key]
  end

  # Set settings.
  # 
  # @api public
  def set(key, value=nil)
    return @settings[key] if value.nil?

    @settings[key] = value
    emit('set:' + key, @settings[key], key)
  end

  # Enable a setting
  # 
  # @api public
  def enable key
    @settings[key] = true
    emit('set:' + key, @settings[key], key)
  end

  # Disable a setting
  # 
  # @api public
  def disable key
    @settings[key] = false
    emit('set:' + key, @settings[key], key)
  end

  # Checks if a setting is enabled
  #
  # @api public
  def enabled key
    @settings[key] != false
  end

  # Checks if a setting is disabled
  #
  # @api public
  def disabled key
    @settings[key] == false
  end

  # Configure callbacks.
  #
  # @api public
  def configure env, fn
    if env.class == Method
      env.call self
    elsif env == process[:env].NODEENV
      fn.call self
    end

    self
  end

  # Initializes everything related to the message dispatcher.
  # 
  # @api private
  def initStore
    @handshaken = {}
    @connected = {}
    @open = {}
    @closed = {}
    @closedA = []
    @rooms = {}
    @roomClients = {}

    [
      'handshake', 
      'connect',
      'open',
      'join',
      'leave',
      'close',
      'dispatch',
      'disconnect'
    ].each { | which |
      store.subscribe(which) { | *args | 
        $stderr.puts YAML.dump(args)
        case args.length
          when 1
            self.method("on#{which.capitalize}").call(args[0]) 
          when 2
            self.method("on#{which.capitalize}").call(args[0], args[1]) 
          when 3
            self.method("on#{which.capitalize}").call(args[0], args[1], args[2]) 
        end
      }
    }
  end

  # Called when a client handshakes.
  # 
  # @param text
  def onHandshake(id, data)
    @handshaken[id] = data
  end

  # Called when a client connects (ie: transport first opens)
  # 
  # @api private
  def onConnect id
    @connected[id] = true
  end

  # Called when a client opens a request in a different node.
  # 
  # @api private
  def onOpen id
    @open[id] = true

    if @closed[id]

      @closedA.reject! do | x | 
        x == id 
      end
      
      store.unsubcribe('dispatch:' + @id) do | x | 
        @closed.delete id 
      end
    end

    if @transports[id]
      @transports[id].discard
      @trasnports[id] = nil
    end
  end
 
  # Called when a message is sent to a namespace and/or room.
  # 
  # @api private
  def onDispatch room, packet, volatile, exceptions
    if @rooms[room]
      @rooms.each_index { | i |
        id = @rooms[room][i]
        
        unless exceptions.index(id)
          if @transports[id] and @transports[id].open
            @transports[id].onDispatch packet, volatile
          elsif not volatile
            onClientDispatch id, packet
          end
        end
      }
    end
  end      

  # Called when a client joins a nsp / room.
  # 
  # @api private
  def onJoin id, name
    @roomClients[id] = {} if @roomClients[id].nil?
    @rooms[name] = [] if @rooms[name].nil?

    @rooms[name] << id unless @rooms[name].index(id)
    @roomClients[id][name] = true
  end

  # Called when a client leaves a nsp / room.
  # 
  # @param private
  def onLeave id, room
    if @rooms[room]
      @rooms[room].reject! { | x | x == id }
      @roomClients[id].delete room
    end
  end

  # Called when a client closes a request in different node.
  # 
  # @api private
  def onClose id
    $stderr.puts 'class >>> ', id.class
    if @open[id]
      @open.delete id
    end

    @closed[id] = []
    @closedA << id

    @funMap['dispatch:' + id] = store.subscribe('dispatch:' + id) do | packet, volatile |
      onClientDispatch(id, packet) if not volatile
    end
  end

  # Dispatches a message for a closed client.
  # 
  # @api private
  def onClientDispatch id, packet
    if @closed[id]
      @closed[id] << packet
    end
  end

  # Receives a message for a client.
  # 
  # @api private
  def onClientMessage id, packet
    if @namespaces[packet.endpoint]
      @namespaces[packet.endpoint].handlePacket id, packet
    end
  end

  # Fired when a client disconnects (not triggered).
  # 
  # @api private
  def onClientDisconnect(id, reason, bool = true)
    @namespaces.each { | name, value |
      value.handleDisconnect(id, reason) if @roomClients[id] and @roomClients[id][name]
    }

    onDisconnect id
  end

  # Called when a client disconnects.
  # 
  # @param text
  def onDisconnect(id, local=nil)
    @handshaken.delete id

    @open.delete(id) if @open[id]
    @connected.delete(id) if @connected[id]

    if @tranports and @transports[id]
      @transports[id].discard
      @transports.delete id
    end

    if @closed[id]
      @closed.delete id
      @closedA.reject! { | x | x == id }
    end

    if @roomClients[id]
      @roomClients[id].each { | room, value |
        @rooms.reject! { | x | x == id }
      }
    end

    store.destroyClient id, get('client store expiration')

    store.unsubscribe('dispatch:' + id, @funMap['dispatch:' + id])

    if local
      store.unsubscribe('message:' + id, @funMap['message:' + id])
      store.unsubscribe('disconnect:' + id, @funMap['disconnect:' + id])
    end
  end

  # Handles an HTTP request.
  # 
  # @api private
  def handleRequest req, res
    data = checkRequest req
 
    unless data
      @oldListeners.each { | which |
        which req, res
      }
 
      return
    end
 
    if data.static || !data.transport && !data.protocol
      if data.static && enabled('browser client')
        handleClientRequest req, res, data
      else
        res.writeHead 200
        res.end 'Welcome to socket.io'
 
        log.info 'unhandled socket.io url'
      end
 
      return
    end
 
    if data.protocol != $protocol
      res.writeHead 500
      res.end 'Protocol version not supported.'
 
      log.info 'client protocol version unsupported'
    else
      if data[:id]
        handleHTTPRequest data, req, res
      else
        handleHandshake data, req, res
      end
    end
  end

  # Handles an HTTP Upgrade.
  # 
  # @api private
  def handleUpgrade req, socket, head
    data = checkRequest req

    unless data
      if enabled('destroy upgrade')
        socket.doEnd
        log.debug 'destroying non-socket.io upgrade'
      end

      return
    end

    req['head'] = head

    handleClient data, req
  end

  # Handles a normal handshaken HTTP request (eg: long-polling)
  # 
  # @api private
  def handleHTTPRequest(data, req, res)
    req[res] = res
    handleClient(data, req)
  end

  # Intantiantes a new client.
  # 
  # @api private
  def handleClient data, req
    socket = req.socket
 
    if data.query.respond_to? :disconnect
      if @transports[data[:id]] && @transports[data[:id]].open
        @transports[data[:id]].onForcedDisconnect
      else
        store.publish('disconnect-force:' + data[:id])
      end 
 
      return
    end 
 
    unless get('transports').index(data.transport)
      log.warn 'unknown transport: "' + data.transport + '"'
      req.connection.doEnd
      return
    end 
 
    transport = eval("Transports::#{transportLookup data.transport}").new self, data, req

    handshaken = @handshaken[data[:id]]
 
    if handshaken
      if transport.open
        if @closed[data[:id]] && @closed[data[:id]].length > 0
          transport.payload(@closed[data[:id]])
          @closed[data[:id]] = []
        end
 
        onOpen(data[:id])
        store.publish('open', data[:id])
        @transports[data[:id]] = transport
      end
 
      unless @connected[data[:id]]
        onConnect data[:id]
        store.publish('connect', data[:id])

        # flag as used
        handshaken.delete issued
        onHandshake(data[:id], handshaken)
        store.publish('handshake', data[:id], handshaken)

        #initialize the socket for all namespaces
        @namespaces.each do | which |
          socket = which.socket(data[:id], true)
 
          # echo back connect packet and fire connection event
          which.handlePacket(data[:id], :type => 'connect')
        end 
 
        @funMap['message:' + data[:id]] = store.subscribe('message:' + data[:id]) do | packet | 
          onClientMessage(data[:id], packet)
        end
 
        @funMap['disconnect:' + data[:id]] = store.subscribe('disconnect:' + data[:id]) do | reason | 
          onClientDisconnect(data[:id], reason)
        end
      end
    else
      if transport.open
        transport.doError('client not handshaken', 'reconnect')
      end
 
      transport.discard
    end
 
  end

  # Dictionary for static file serving
  # 
  # @api public
  def doStatic
    base = File.dirname(__FILE__).split('/')[0..-2].join('/') + '/node_modules/socket.io-client/dist'

    @static = {
      :cache => {},
      :paths => {
        '/static/flashsocket/WebSocketMain.swf' => base + '/WebSocketMain.swf',
        '/static/flashsocket/WebSocketMainInsecure.swf' => base + '/WebSocketMainInsecure.swf',
        '/socket.io.js' => base + '/socket.io.js',
        '/socket.io.js.min' => base + '/socket.io.min.js'
      }, 
      :mime => {
        'js' => {
          'contentType' => 'application/javascript',
          'encoding' => 'utf8'
        },
        'swf' => {
          'contentType' => 'application/x-shockwave-flash',
          'encoding' => 'binary'
        }
      }
    }
  end

  # Serves the client.
  #
  # @api private
  def handleClientRequest req, res, data
    # rb only
    #
    #  Scoping permissions require me to reflect this
    @res = res
    @req = req

    _static = @static

    extension = data.path.split('.').pop
    file = data.path + (enabled('browser client minification') && extension == 'js' ? '.min' : '')
    location = _static.paths[file]
    cache = _static.cache[file]

    # Writes a response, safely
    # 
    # @api private
    def write(status, headers = nil, content = nil, encoding = 'utf8')
      @res.writeHead(status, headers || nil)
      @res.doEnd(content || '', encoding || nil)
    end

    def serve cache, extension
      if @req.headers['if-none-match'] == cache.Etag
        return write(304)
      end
      
      mime = @static.mime[extension]
      headers = {
        'Content-Type' => mime.contentType,
        'Content-Length' => cache['length']
      }

      if enabled('browser client etag') && cache.Etag
        headers.Etag = cache.Etag
      end 

      write(200, headers, cache.content, mime.encoding)
      log.debug 'served static ' #+ data.path
    end

    if get('browser client handler')
      get('browser client handler').call(req, res)
    elsif @cache.nil?
      begin
        file = File.open location, 'rb' 
        data = file.read
      rescue
        write(500, nil, 'Error serving static ' + data.path)
        log.warn('Can\'t cache ' + data.path)
        return
      end

      cache = @static.cache[file] = {
        'content' => data,
        'length' => data.length.to_s,
        'Etag' => @@client.version
      }

      serve cache, extension
    else
      serve cache, extension
    end 

  end

  # Generates a session id.
  #
  # @api private
  def generateID
    # Please note. Ruby's random implementation
    # seeds before a proper fork.  This means that
    # if you rely on the built in random, you will
    # get the some MT sequence on a per thread/fork
    # basis per instance.  Because of this, we are
    # using a UUID generator
    UUID.generate.hex
  end

  # Handles a handshake request.
  #
  # @api private
  def handleHandshake data, req, res
    def writeErr status, message
      if (data.query.jsonp) 
        res.writeHead(200, 'Content-Type' => 'application/javascript')
        res.doEnd('io.j[' + data.query[:jsonp] + '](new Error("' + message + '"));')
      else
        res.writeHead status
        res.doEnd message
      end
    end

    def doError err
      writeErr 500, 'handshake error'
      log.warn "handshake error #{err}"
    end

    unless verifyOrigin req
      writeErr 403, 'handshake bad origin'
      return
    end

    handshakeData = handshakeData data

    authorize(handshakeData) { |err, authorized, newData|
      if err 
        return error err
      end
 
      if authorized
        id = generateID
        hs = [ id, 
              get('heartbeat timeout') || '',
              get('close timeout') || '',
              transports(data).join(',')
            ].join(':')
 
        if data.query[:jsonp]
          hs = 'io.j[' + data.query.jsonp + '](' + JSON.stringify(hs) + ');'
          res.writeHead(200, { 'Content-Type' => 'application/javascript' })
        else 
          res.writeHead 200
        end 
 
        res.doEnd hs
 
        onHandshake(id, newData || handshakeData)
        store.publish('handshake', id, newData || handshakeData)
 
        log.info('handshake authorized', id)
      else 
        writeErr(403, 'handshake unauthorized')
        log.info('handshake unauthorized')
      end 
    }
  end

  # Gets normalized handshake data
  #
  # @api private
  def handshakeData data
    connection = data.request.connection
    connectionAddress = {}
 
    if connection['remoteAddress']
      connectionAddress = {
        :address => connection['remoteAddress'],
        :port => connection['remotePort']
      } 
    elsif connection.socket and connection.socket['remoteAddress']
      connectionAddress = {
        :address => connection.socket['remoteAddress'],
        :port => connection.socket['remotePort']
      }
    end
 
    {
      :headers => data[:headers],
      :address => connectionAddress,
      :time => DateTime.now.to_s,
      :query => data.query,
      :url => data.request.url,
      :xdomain => data.request.headers[:origin] ? true : false,
      :secure => data.request.connection['secure'],
      :issued => Time.new.to_f
    }
  end

  # Verifies the origin of a request.
  #
  # @api private
  def verifyOrigin request
    origin = request.headers[:origin] || request.headers[:referer]
    origins = get('origins')
    
    origin = '*' if origin.nil? 
 
    return true if origins.index('*:*')
 
    if origin
      begin
        parts = url.parse origin
 
        ok = origins.index(parts[:host] + ':' + parts[:port]) || origins.index(parts[:host] + ':*') || origins.index('*:' + parts[:port])
        log.warn('illegal origin: ' + origin) if !ok 
        return ok
      rescue;
        log.warn 'error parsing origin'
      end
    else
      log.warn 'origin missing from handshake, yet required by config'
    end
 
    false
  end
 
  # Handles an incoming packet.
  #
  # @api private
  def handlePacket sessid, packet
    of(packet[:endpoint] || '').handlePacket sessid, packet
  end

  # Performs authentication.
  #
  # @param Object client request data
  # @api private
  def authorize(data, &fn)
    if get('authorization')
      
      get('authorization').call(data, lambda { | err, authorized |
        log.debug('client ' + authorized ? 'authorized' : 'unauthorized')
        fn(err, authorized)
      })
    else
      log.debug 'client authorized'
      fn.call nil, true
    end
    self
  end

  # Retrieves the transports adviced to the user.
  #
  # @api private
  def transports(data = nil)
    (get 'transports').each_value.select { | which |
      which # and ( !which.checkClient or which.checkClient data )
    }
  end

  # rb only
  def transportLookup which
    (get 'transports').invert[which]
  end

  # Checks whether a request is a socket.io one.
  # 
  # @return [Object] a client request data object or `false`
  # @api private
  @@regexp = /^\/([^\/]+)\/?([^\/]+)?\/?([^\/]+)?\/?$/
  def checkRequest req
    resource = get('resource')
 
    if (req.url[0..resource.length - 1] == resource) 
      uri = URI.parse req.url[resource.length..-1]
      path = uri.path || ''
      pieces = path.match(@@regexp)
   
      # client request data
      data = {
        :query => uri.query || {},
        :headers => req.headers,
        :request => req,
        :path => path
      }
 
      unless pieces.nil?
        data.protocol = pieces[1].to_i
        data.transport = pieces[2]
        data[:id] = pieces[3]
        data.static = !!@static[:paths][path]
      end
 
      return data
    end 
 
    false
  end

  # Declares a socket namespace
  # 
  # @api public
  def of nsp
    @namespaces[nsp] = SocketNamespace.new(self, nsp) unless @namespaces[nsp]
  end
end
