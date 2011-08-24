
class Manager

  attr_accessor :rooms
  attr_accessor :static

  def initialize(server, options = nil)
    @server = server
    @namespaces = {}
    @sockets = of('')

    @settings = {
      'origins' => '*:*',
      'log' => true,
      'store' => Memory.new,
      'logger' => Logger.new,
      'heartbeats' => true,
      'resource' => '/socket.io',
      'transports' => [ 'WebSocket' 'HTMLFile' 'XhrPolling' 'JsonpPolling' ],
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

    server.on('request') { |req, res|
      handleRequest req, res
    }

    server.on('upgrade') { |req, socket, head|
      handleUpgrade(req, socket, head)
    }

    server.on('close') { | x |
      #clearInterval(self.gc)
    }

=begin
    transports.each { | trans | 
      eval(trans).init if eval(trans).responds_to? :init
    }
=end

    log.info('socket.io started')
    
    #rb: only
    doStatic
  end

  def handshakeData; end

  def store; get 'store'; end

  def log
    return nil if disabled :log
    logger = get 'logger'
    logger.level = get 'log level'
    logger
  end

  def get key; @settings[key]; end

  def emitKey(key)
    emit("set:#{key}", @settings[key], key)
  end

  def set(key, value=nil)
    return @settings[key] if value.nil?

    @settings[key] = value
    emitKey key
  end

  def enable key
    @settings[key] = true
    emitKey key
  end

  def disable key
    @settings[key] = false
    emitKey key
  end

  def enabled key
    @settings[key]
  end

  def disabled key
    @settings[key] == false
  end

  def transports data 
    transp = @settings['transports']

    transp.accept { |transport|
      transport && (!transport.checkClient || transport.checkClient(data))
    }
  end

  def configure env, fn
    if env.class == Method
      env.call
    elsif env == process[:env].NODEENV
      fn.call
    end

    self
  end

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
      store.subscribe(which) { | *args | self.send("on#{which.capitalize}", args) }
    }
  end

  def onHandshake(id, data)
    @handshaken[id] = data
  end

  def onConnect id
    @connected[id] = true
  end

  def onOpen id
    @open[id] = true

    if @closed[id]

      @closedA.reject! { | x | x == id }
      
      @store.unsubcribe("dispatch:#{@id}") { | x | 
        @closed.delete id 
      }
    end

    if @transports[id]
      @transports[id].discard
      @trasnports[id] = nil
    end
  end

  def onDispatch room, packet, volatile, exceptions
    if @rooms[room]
      @rooms.each_index { | i |
        id = @rooms[room][i]
        
        unless exceptions.index[id]
          if @transports[id] and @transports[id].open
            @transports[id].onDispatch packet, volatile
          elsif not volatile
            onClientDispatch id, packet
          end
        end
      }
    end
  end      

  def onJoin id, name
    @roomClients[id] = {} if @roomClients[id].nil?
    @rooms[name] = [] if @rooms[name].nil?

    @rooms[name] << id unless @rooms[name].index(id)
    @roomClients[id][name] = true
  end

  def onLeave id, room
    if @rooms[room]
      @rooms[room].reject! { | x | x == id }
      @roomClients[id].delete room
    end
  end

  def onClose id
    if @open[id]
      @open.delete id
    end

    @closed[id] = []
    @closedA << id

    @store.subscribe("dispatch:#{@id}") { | packet, volatile |
      onClientDispatch(id, packet) if not volatile
    }
  end

  def onClientDispatch id, packet
    if @closed[id]
      @closed[id] << packet
    end
  end

  def onClientMessage id, packet
    if @namespaces[packet[:endpoint]]
      @namespaces[packet[:endpoint]].handlePacket id, packet
    end
  end

  def onClientDisconnect id, reason
    @namespaces.each { | name, value |
      value.handleDisconnect(id, reason) if @roomClients[id][name]
    }

    onDisconnect id
  end

  def onDisconnect(id, local=nil)
    @handshaken.delete id

    @open.delete(id) if @open[id]
    @connected.delete(id) if @connected[id]

    if @transports[id]
      @transports[id].discard
      @transports.delete id
    end

    if @closed[id]
      @closed.delete id
      @closedA.reject! { | x | x == id }
    end

    if @roomClientsp[id]
      @roomClients[id].each { | room, value |
        @rooms.reject! { | x | x == id }
      }
    end

    @store.destroyClient id, get('client store expiration')

    @store.unsubscribe("dispatch:#{@id}")

    if local
      @store.unsubscribe("message:#{@id}")
      @store.unsubscribe("disoconnect:#{@id}")
    end
  end

  def handleRequest req, res
    data = checkRequest req
 
    unless data
      @oldListeneres.each { | which |
        which req, res
      }
 
      return
    end
 
    if data[:static] || !data[:transport] && !data[:protocol]
      if data[:static] && enabled('browser client')
        handleClientRequest req, res, data
      else
        res.writeHead 200
        res.end 'Welcomet to socket.io'
 
        log.info 'unhandled socket.io url'
      end
 
      return
    end
 
    if data[:protocol] != protocol
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

  def handleUpgrade req, socket, head
    data = checkRequest req

    if !data
      if enabled('destroy upgrade')
        socket.doEnd
        log.debug 'destroying non-socket.io upgrade'
      end

      return
    end

    req[:head] = head

    handleClient data, req
  end

  def handleHTTPRequest data, req, ret
    req[res] = res
    handleClient data, req
  end

  def handleClient data, req

    socket = req[:socket]
    store = @store
 
    if data[:query].respond_to? :disconnect
      if @transports[data[:id]] && @transports[data[:id]].open
        @transports[data[:id]].onForcedDisconnect
      else
        @store.publish "disconnect-force:#{data[:id]}"
      end 
 
      return
    end 
 
    unless get('transports').index(data.transport)
      log.warn 'unknown transport: "' + data.transport + '"'
      req[:connection].doEnd
      return
    end 
 
    transport = @transports[data[:transport]].new data, req
 
    if @handshaken[data[:id]]
      if transport.open
        if @closed[data[:id]] && @closed[data[:id]].length > 0
          transport.payload(@closed[data[:id]])
          @closed[data[:id]] = []
        end
 
        onOpen(data[:id])
        @store.publish('open', data[:id])
        @transports[data[:id]] = transport
      end
 
      unless @connected[data[:id]]
        onConnect data[:id]
        @store.publish 'connect', data[:id]
 
        #initialize the socket for all namespaces
        @namespaces.each { | which |
          socket = which.socket data[:id], true
 
          # echo back connect packet and fire connection event
          which.handlePacket(data[:id], :type => 'connect')
        }
 
        @store.subscribe("message:#{data[:id]}") { | packet | 
          onClientMessage(data[:id], packet)
        }
 
        @store.subscribe("disconnect:#{data[:id]}") { |reason| 
          onClientDisconnect(data[:id], reason)
        }
      end
    else
      if transport.open
        tranport.error 'client not handshaken', 'reconnect'
      end
 
      transport.discard
    end
 
  end

  def doStatic
    @static = {
      :cache => {},
      :paths => {
        # '/static/flashsocket/WebSocketMain.swf' => client[:dist] + '/WebSocketMain.swf',
        # '/static/flashsocket/WebSocketMainInsecure.swf' => client[:dist] + '/WebSocketMainInsecure.swf',
        # '/socket.io.js' => client[:dist] + '/socket.io.js',
        # '/socket.io.js.min' => client[:dist]+ '/socket.io.min.js'
        '/static/flashsocket/WebSocketMain.swf' => '/WebSocketMain.swf',
        '/static/flashsocket/WebSocketMainInsecure.swf' => '/WebSocketMainInsecure.swf',
        '/socket.io.js' => '/socket.io.js',
        '/socket.io.js.min' => '/socket.io.min.js'
      }, 
      :mime => {
        :js => {
          'contentType' => 'application/javascript',
          'encoding' => 'utf8'
        },
        :swf => {
           'contentType' => 'application/x-shockwave-flash',
           'encoding' => 'binary'
        }
      }
    }
  end

  def handleClientRequest req, res, data
    _static = @static

    extension = data[:path].split('.').pop
    file = data[:path] + (enabled('browser client minification') && extension == 'js' ? '.min' : '')
    location = _static[:paths][:file]
    cache = _static[:cache][:file]

    def write status, headers, content, encoding
      res.writeHead status, headers || nil
      res.end content || '', encoding || nil
    end

    def serve
      if req[:headers]['if-none-match'] == cache[:Etag]
        return write(304)
      end
      
      mime = _static[:mime][extension]
      headers = {
        'Content-Type' => mime[:contentType],
        'Content-Length' => cache.length
      }

      if enabled('browser client etag') && cache[:Etag]
        headers[:Etag] = cache[:Etag]
      end 

      write 200, headers, cache[:content], mime[:encoding]
      log.debug 'served static ' + data[:path]
    end

    if get('browser client handler')
      get('browser client handler').call(req, res)
    elsif cache.nil?
      fs.readFile location, lambda { |err, data|
        if (err) 
          write 500, nil, 'Error serving static ' + data[:path]
          log.warn "Can't cache " + data[:path] + ', ' + err.message
          return
        end

        cache = @static[:cache][file] = {
          :content => data,
          :length => data.length,
          :Etag => client[:version]
        }

        serve
      }
    else
      serve
    end 

  end

  def generateID
    UUID.generate
  end

  def handleHandshake data, req, res
    def writeErr status, message
      if (data[:query].jsonp) 
        res.writeHead(200, 'Content-Type' => 'application/javascript')
        res.doEnd('io.j[' + data[:query][:jsonp] + '](new Error("' + message + '"));')
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
        id = generateId
        hs = [ id, 
              get('heartbeat timeout') || '',
              get('close timeout') || '',
              transports(data).join(',')
            ].join(':')
 
        if data[:query][:jsonp]
          hs = 'io.j[' + data[:query][:jsonp] + '](' + JSON.stringify(hs) + ');'
          res.writeHead(200, { 'Content-Type' => 'application/javascript' })
        else 
          res.writeHead 200
        end 
 
        res.end hs
 
        onHandshake id, newData || handshakeData
        @store.publish 'handshake', id, newData || handshakeData
 
        log.info 'handshake authorized', id
      else 
        writeErr 403, 'handshake unauthorized'
        log.info 'handshake unauthorized'
      end 
    }
  end

  def handshakeData data
    connection = data[:request][:connection]
    connectionAddress = {}
 
    if connection[:remoteAddress]
      connectionAddress = {
        :address => connection[:remoteAddress],
        :port => connection[:remotePort]
      } 
    elsif connection[:socket] and connection[:socket][:remoteAddress]
      connectionAddress = {
        :address => connection[:socket][:remoteAddress],
        :port => connection[:socket][:remotePort]
      }
    end
 
    {
      :headers => data[:headers],
      :address => connectionAddress,
      :time => DateTime.now.to_s,
      :xdomain => data.request.headers.origin ? true : false,
      :secure => data[:request][:connection][:secure]
    }
  end

  def verifyOrigin request
    origin = request[:header][:origin]
    origins = get('origins')
    
    origin = '*' if origin.nil? 
 
    return true if origins.index('*:*')
 
    if origin
      begin
        parts = url.parse origin
 
        return origins.index(parts[:host] + ':' + parts[:port]) || origins.index(parts[:host] + ':*') || origins.index('*:' + parts[:port])
 
      rescue; end
    end
 
    false
  end
 
  def handlePacket sessid, packet
    of(packet[:endpoint] || '').handlePacket sessid, packet
  end

  def authorize data, fn
    if get('authorization')
      
      get('authorization').call(data, lambda { | err, authorized |
        log.debug('client ' + authorized ? 'authorized' : 'unauthorized')
        fn(err, authorized)
      })
    else
      log.debug 'client authorized'
      fn nil, true
    end
    self
  end
 
  def transports data
    (get 'transports').accept lambda { | which |
      which and ( !which.checkClient or which.checkClient data )
    }
  end
 

  def checkRequest req
    regexp = /^\/([^\/]+)\/?([^\/]+)?\/?([^\/]+)?\/?$/
    resource = get('resource')
 
    if (req.url[0..resource.length] == resource) 
      uri = url.parse(req.url[resource.length..-1], true)
      path = uri.pathname || ''
      pieces = path.match(regexp)
   
      # client request data
      data = {
        :query => uri.query || {},
        :headers => req.headers,
        :request => req,
        :path => path
      }
 
      if (pieces)
        data[:protocol] = pieces[1].to_i
        data[:transport] = pieces[2]
        data[:id] = pieces[3]
        data[:static] = !!@static[:paths][path]
      end
 
      return data
    end 
 
    false
  end

  def of nsp
    @namespaces[nsp] = SocketNamespace.new(self, nsp) unless @namespaces[nsp]
  end
end
