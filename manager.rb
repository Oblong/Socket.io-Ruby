$constants = {
  :transports => [ 'websocket' , 'htmlfile' , 'xhr-polling' , 'jsonp-polling' ]
}

module Manager
  @settings = {
      :origins => '*:*'
    , :log => true
    , :store => MemoryStore.new
    , :logger => Logger.new
    , :heartbeats => true
    , :resource => '/socket.io'
    , :transports => $constants[:transports]
    , :authorization => false
    , 'log level' => 3
    , 'close timeout' => 25
    , 'heartbeat timeout' => 15
    , 'heartbeat interval' => 20
    , 'polling duration' => 20
    , 'flash policy server' => true
    , 'flash policy port' => 843
    , 'destroy upgrade' => true
    , 'browser client' => true
    , 'browser client minification' => false
    , 'browser client etag' => false
    , 'browser client handler' => false
    , 'client store expiration' => 15
  }

  def self.handshakeData; end

  def get key
    @settings[key]
  end

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
    !@settings[key]
  end

  def self.transports data 
    transp = @settings[:transports]
    ret = []

    transp.each { |transport|
      if transport)
        if (!transport.checkClient || transport.checkClient(data)) 
          ret.push transport
        end
      end
    }

    ret
  end

  def configure env, fn
    # TODO
    if env.class == Method
      env.call(self)
    elsif env == process[:env].NODE_ENV
      fn.call(self)
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

    'handshake connect open join leave close dispatch disconnect'.split(' ').each { | which |
      @store.subscribe(which, { | *args | self.send("on#{which.capitalize}", args) }
    }
  end

  def onHandshake(id, data)
    @handshaken[id] = data
  end

  def onConnect(id)
    @connected[id] = true
  end

  def onOpen id
    @open[id] = true

    if @closed[id]

      @closedA.reject! { | x | x == id }
      
      @store.unsubcribe "dispatch:#{@id}" do | x | 
        @closed.delete :id 
      end
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
           else if !volatile
             onClientDispatch id, packet
           end
         end
       }
     end
   end      

   def onJoin id, name
     @roomClients[id] = {} if @roomClients[id].nil?
     @rooms[name] = [] if @rooms[name].nil?

     @rooms[name].push(id)
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
     @closedA.push id

     @store.subscribe "dispatch:#{@id}", { | packet, volatile |
       onClientDispatch(id, packet) if not volatile
     }
   end

   def onClientDispatch id, packet
     if @closed[id]
       @closed[id].push packet
     end
   end

   def onClientMessage id, packet
     if @namespaces[packet[:endpoint]]
       @namespaces[packet[:endpoint].handlePacket id, packet
     end
   end

   def onClientDisconnect id, reason
     onDisconnect id

     @namespaces.each { | name, value |
       value.handleDisconnect(id, reason) if @roomClients[id][name]
     }
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

     @store.destroyClient id, @get('client store expiration')

     @store.unsubscribe("dispatch:#{@id}")

     if local
       @store.unsubscribe("message:#{@id}")
       @store.unsubscribe("disoconnect:#{@id}")
     end
  end

  def handleRequest req, res
   data = checkRequest req

   unless data
     # TODO
     @oldListeneres.each { | which |
       which.call(@server, req, res)
     }

     return
   end

   if data[:static] || !data[:transport] && !data[:protocol]
     if data[:static] && @enabled('browser client')
       handleClientRequest req, res, data
     else
       res.writeHead 200
       res.end 'Welcomet to socket.io'

       Logger.info 'unhandled socket.io url'
     end

     return
   end

   if data[:protocol] != protocol
     res.writeHead 500
     res.end 'Protocol version not supported.'

     Logger.info 'client protocol version unsupported'
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
     if @enabled('destroy upgrade')
       socket.end
       Logger.debug 'destroying non-socket.io upgrade'
     end

     return
   end

   req[:head] = head

   handleClient data, req
  end

  def handleHTTPRequest data, req, ret
   req[res] = res
   @handleClient data, req
  end

  def handleClient data, req
   socket = req[:socket]
   store = @store

   #TODO
   if data.query.respond_to? :disconnect)
     if @transports[data[:id]] && @transports[data[:id]].open
       @transports[data[:id]].onForcedDisconnect
     else
       @store.publish "disconnect-force:#{data[:id]}"
     end 

     return
   end 

   if !get('transports').index(data.transport))
     Logger.warn 'unknown transport: "' + data.transport + '"'
     req.connection.end
     return
   end 

   transport = @transports[data[:transport]].new data, req

   if @handshaken[data[:id]]
     if transport.open
       if @closed[data[:id]] && @closed[data[:id]].length
         transport.payload(@closed[data[:id]])
         @closed[data[:id]] = []
       end

       onOpen(data[:id])
       @store.publish('open', data[:id])
       @transports[data[:id]] = transport
     end

   if !@connected[data[:id]]
     onConnect data[:id]
     @store.publish 'connect', data[:id]

     #initialize the socket for all namespaces
     @namespaces.each { | which |
       socket = which.socket data[:id], true

       # echo back connect packet and fire connection event
       which.handlePacket data[:id], { type: 'connect' }
     }

     @store.subscribe 'message:' + data[:id], { |packet| 
       onClientMessage data[:id], packet
     }

     @store.subscribe 'disconnect:' + data[:id], { |reason| 
       onClientDisconnect data[:id], reason
     }
   else
     if transport.open
       tranport.error 'client not handshaken', 'reconnect'
     end

     transport.discard
   end
  end

  Manager[:static] = {
   :cache => {},
   :paths => {
     '/static/flashsocket/WebSocketMain.swf' => client[:dist] + '/WebSocketMain.swf',
     '/static/flashsocket/WebSocketMainInsecure.swf' => client[:dist] + '/WebSocketMainInsecure.swf',
     '/socket.io.js' => client[:dist] + '/socket.io.js',
     '/socket.io.js.min' => client[:dist]+ '/socket.io.min.js'
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



  def handleClientRequest req, res, data
    # TODO
    static = Manager.static

    extension = data[:path].split('.').pop
    file = data[:path] + (@enabled('browser client minification')
       && extension == 'js' ? '.min' : '')
    location = static.paths[file]
    cache = static.cache[file]

    def write status, headers, content, encoding
      res.writeHead status, headers || nil
      res.end content || '', encoding || nil
    end

    def serve
      if req[:headers]['if-none-match'] == # cache.Etag) {
        return write 304
      end
      
      mime = static[mime][extension]
      headers = {
        'Content-Type' => mime[:contentType],
        'Content-Length' => cache.length
      }

      if @enabled('browser client etag') && cache[:Etag]
        headersp[:Etag] = cache[:Etag]
      end 

      write 200, headers, cache[:content], mime[:encoding]
      Logger.debug 'served static ' + data.path
    end

    if get('browser client handler')
      #@get('browser client handler').call(this, req, res)
    else if cache.nil?
      fs.readFile location, { |err, data|
        if (err) 
          write 500, null, 'Error serving static ' + data.path
          Logger.warn "Can\'t cache " + data.path +', ' + err.message
          return
        end

        cache = Manager.static.cache[file] = {
          :content => data
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
      if (data.query.jsonp) 
        res.writeHead(200, { 'Content-Type' => 'application/javascript' })
        res.end('io.j[' + data[:query][:jsonp] + '](new Error("' + message + '"));')
      else
        res.writeHead(status)
        res.end(message)
      end
    end

    def doError err
      writeErr 500, 'handshake error'
      Logger.warn "handshake error #{err}"
    end

    unless verifyOrigin req
      writeErr 403, 'handshake bad origin'
      return
    end

    handshakeData = handshakeData data

    authorize handshakeData, { |err, authorized, newData|
      if err 
        return error(err
      end
 
      if authorized
        id = generateId
        hs = [ id, 
              get('heartbeat timeout') || '',
              get('close timeout') || ''
              transports(data).join(',')
            ].join(':')
 
        if data[:query][:jsonp]
          hs = 'io.j[' + data[:query][:jsonp] + '](' + JSON.stringify(hs) + ');'
          res.writeHead 200, { 'Content-Type' => 'application/javascript' })
        else 
          res.writeHead 200
        end 
 
        res.end hs
 
        onHandshake id, newData || handshakeData
        @store.publish 'handshake', id, newData || handshakeData
 
        self.log.info('handshake authorized', id)
      else 
        writeErr 403, 'handshake unauthorized'
        self.log.info('handshake unauthorized')
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
      :headers => data[:headers]
      :address => connectionAddress,
      :time => DateTime.now.to_s
      # TODO
      :xdomain: !!data.request.headers.origin
      :secure => data[:request][:connection][:secure]
    }
  end
 
  def verifyOrigin request
    origin = request[:header][:origin]
    origins = get('origins')
    # , origins = @get('origins')
    
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
    if get('authorize')
      #TODO
      get('authorization')
      get('authorization').call(this, data, function (err, authorized) {
        self.log.debug('client ' + authorized ? 'authorized' : 'unauthorized')
        fn(err, authorized)
      })
    else
      Logger.debug 'client authorized'
      fn nil, true
    end
    self
  end
 
  def transports data
    (get 'transports').accept { | which |
      which and ( !which.checkClient or which.checkClient data )
    }
  end
 
 
  #TODO
  regexp = /^\/([^\/]+)\/?([^\/]+)?\/?([^\/]+)?\/?$/
  def checkRequeest req
   resource = get('resource')
 
   # TODO
   if (req.url.substr(0, resource.length) == resource) 
      uri = url.parse(req.url.substr(resource.length), true)
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
        # TODO
        # data[:static] = !!Manager.static.paths[path]
      end
 
      return data
    end 
 
    false
  end
 
  def of nsp
    @namespaces[nsp] = SocketNamespace.new nsp unless @namespaces[nsp]
  end
end
