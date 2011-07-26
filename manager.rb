$constants = {
  :transports => [ 'websocket' , 'htmlfile' , 'xhr-polling' , 'jsonp-polling' ]
}

module Manager
  @settings = {
      :origins=> '*:*'
    , :log=> true
#    , :store=> new MemoryStore
#    , :logger=> new Logger
    , :heartbeats=> true
    , :resource=> '/socket.io'
    , :transports=> $constants[:transports]
    , :authorization=> false
    , 'log level'=> 3
    , 'close timeout'=> 25
    , 'heartbeat timeout'=> 15
    , 'heartbeat interval'=> 20
    , 'polling duration'=> 20
    , 'flash policy server'=> true
    , 'flash policy port'=> 843
    , 'destroy upgrade'=> true
    , 'browser client'=> true
    , 'browser client minification'=> false
    , 'browser client etag'=> false
    , 'browser client handler'=> false
    , 'client store expiration'=> 15
  };

  def self.handshakeData; end

  def get key
    @settings[key]
  end

  def emitKey(key)
    # FIRE
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
      if (transport) 
        if (!transport.checkClient || transport.checkClient(data)) 
          ret.push(transport);
        end
      end
    end 

    ret
  end
=begin
/**
 * Configure callbacks.
 *
 * @api public
 */

Manager.prototype.configure = function (env, fn) {
  if ('function' == typeof env) {
    env.call(this);
  } else if (env == process.env.NODE_ENV) {
    fn.call(this);
  }

  return this;
};
=end
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

       #this.closedA.splice(this.closedA.indexOf(id), 1);
       
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
      @onDisconnect id

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
      @oldListeneres.each { | which |
        #this.oldListeners[i].call(this.server, req, res);
      }

      return
    end


=begin
  if (data.static || !data.transport && !data.protocol) {
    if (data.static && this.enabled('browser client')) {
      this.handleClientRequest(req, res, data);
    } else {
      res.writeHead(200);
      res.end('Welcome to socket.io.');

      this.log.info('unhandled socket.io url');
    }

    return;
  }

  if (data.protocol != protocol) {
    res.writeHead(500);
    res.end('Protocol version not supported.');

    this.log.info('client protocol version unsupported');
  } else {
    if (data.id) {
      this.handleHTTPRequest(data, req, res);
    } else {
      this.handleHandshake(data, req, res);
    }
  }
};
=end
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
=begin
/**
 * Intantiantes a new client.
 *
 * @api private
 */

Manager.prototype.handleClient = function (data, req) {
  var socket = req.socket
    , store = this.store
    , self = this;

  if (undefined != data.query.disconnect) {
    if (this.transports[data.id] && this.transports[data.id].open) {
      this.transports[data.id].onForcedDisconnect();
    } else {
      this.store.publish('disconnect-force:' + data.id);
    }
    return;
  }

  if (!~this.get('transports').indexOf(data.transport)) {
    this.log.warn('unknown transport: "' + data.transport + '"');
    req.connection.end();
    return;
  }

  var transport = new transports[data.transport](this, data, req);

  if (this.handshaken[data.id]) {
    if (transport.open) {
      if (this.closed[data.id] && this.closed[data.id].length) {
        transport.payload(this.closed[data.id]);
        this.closed[data.id] = [];
      }

      this.onOpen(data.id);
      this.store.publish('open', data.id);
      this.transports[data.id] = transport;
    }

    if (!this.connected[data.id]) {
      this.onConnect(data.id);
      this.store.publish('connect', data.id);

      // initialize the socket for all namespaces
      for (var i in this.namespaces) {
        var socket = this.namespaces[i].socket(data.id, true);

        // echo back connect packet and fire connection event
        if (i === '') {
          this.namespaces[i].handlePacket(data.id, { type: 'connect' });
        }
      }

      this.store.subscribe('message:' + data.id, function (packet) {
        self.onClientMessage(data.id, packet);
      });

      this.store.subscribe('disconnect:' + data.id, function (reason) {
        self.onClientDisconnect(data.id, reason);
      });
    }
  } else {
    if (transport.open) {
      transport.error('client not handshaken', 'reconnect');
    }

    transport.discard();
  }
};

/**
 * Dictionary for static file serving
 *
 * @api public
 */

Manager.static = {
    cache: {}
  , paths: {
        '/static/flashsocket/WebSocketMain.swf': client.dist + '/WebSocketMain.swf'
      , '/static/flashsocket/WebSocketMainInsecure.swf':
          client.dist + '/WebSocketMainInsecure.swf'
      , '/socket.io.js':  client.dist + '/socket.io.js'
      , '/socket.io.js.min': client.dist + '/socket.io.min.js'
    }
  , mime: {
        'js': {
            contentType: 'application/javascript'
          , encoding: 'utf8'
        }
      , 'swf': {
            contentType: 'application/x-shockwave-flash'
          , encoding: 'binary'
        }
    }
};

/**
 * Serves the client.
 *
 * @api private
 */

Manager.prototype.handleClientRequest = function (req, res, data) {
  var static = Manager.static
    , extension = data.path.split('.').pop()
    , file = data.path + (this.enabled('browser client minification')
        && extension == 'js' ? '.min' : '')
    , location = static.paths[file]
    , cache = static.cache[file];

  var self = this;

  /**
   * Writes a response, safely
   *
   * @api private
   */

  function write (status, headers, content, encoding) {
    try {
      res.writeHead(status, headers || null);
      res.end(content || '', encoding || null);
    } catch (e) {}
  }

  function serve () {
    if (req.headers['if-none-match'] === cache.Etag) {
      return write(304);
    }

    var mime = static.mime[extension]
      , headers = {
      'Content-Type': mime.contentType
    , 'Content-Length': cache.length
    };

    if (self.enabled('browser client etag') && cache.Etag) {
      headers.Etag = cache.Etag;
    }

    write(200, headers, cache.content, mime.encoding);
    self.log.debug('served static ' + data.path);
  }

  if (this.get('browser client handler')) {
    this.get('browser client handler').call(this, req, res);
  } else if (!cache) {
    fs.readFile(location, function (err, data) {
      if (err) {
        write(500, null, 'Error serving static ' + data.path);
        self.log.warn('Can\'t cache '+ data.path +', ' + err.message);
        return;
      }

      cache = Manager.static.cache[file] = {
        content: data
      , length: data.length
      , Etag: client.version
      };

      serve();
    });
  } else {
    serve();
  }
};

/**
 * Generates a session id.
 *
 * @api private
 */

Manager.prototype.generateId = function () {
  return Math.abs(Math.random() * Math.random() * Date.now() | 0).toString()
    + Math.abs(Math.random() * Math.random() * Date.now() | 0).toString();
};

/**
 * Handles a handshake request.
 *
 * @api private
 */

Manager.prototype.handleHandshake = function (data, req, res) {
  var self = this;

  function writeErr (status, message) {
    if (data.query.jsonp) {
      res.writeHead(200, { 'Content-Type': 'application/javascript' });
      res.end('io.j[' + data.query.jsonp + '](new Error("' + message + '"));');
    } else {
      res.writeHead(status);
      res.end(message);
    }
  };

  function error (err) {
    writeErr(500, 'handshake error');
    self.log.warn('handshake error ' + err);
  };

  if (!this.verifyOrigin(req)) {
    writeErr(403, 'handshake bad origin');
    return;
  }

  var handshakeData = this.handshakeData(data);

  this.authorize(handshakeData, function (err, authorized, newData) {
    if (err) return error(err);

    if (authorized) {
      var id = self.generateId()
        , hs = [
              id
            , self.get('heartbeat timeout') || ''
            , self.get('close timeout') || ''
            , self.transports(data).join(',')
          ].join(':');

      if (data.query.jsonp) {
        hs = 'io.j[' + data.query.jsonp + '](' + JSON.stringify(hs) + ');';
        res.writeHead(200, { 'Content-Type': 'application/javascript' });
      } else {
        res.writeHead(200);
      }

      res.end(hs);

      self.onHandshake(id, newData || handshakeData);
      self.store.publish('handshake', id, newData || handshakeData);

      self.log.info('handshake authorized', id);
    } else {
      writeErr(403, 'handshake unauthorized');
      self.log.info('handshake unauthorized');
    }
  })
};

=end
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
 #       :time: (new Date).toString()
#        :xdomain: !!data.request.headers.origin
        :secure => data[:request][:connection][:secure]
      }
    end
=begin
/**
 * Verifies the origin of a request.
 *
 * @api private
 */

Manager.prototype.verifyOrigin = function (request) {
  var origin = request.headers.origin
    , origins = this.get('origins');

  if (origin === 'null') origin = '*';

  if (origins.indexOf('*:*') !== -1) {
    return true;
  }

  if (origin) {
    try {
      var parts = url.parse(origin);

      return
        ~origins.indexOf(parts.host + ':' + parts.port) ||
        ~origins.indexOf(parts.host + ':*') ||
        ~origins.indexOf('*:' + parts.port);
    } catch (ex) {}
  }

  return false;
};
=end
    def handlePacket sessid, packet
      of(packet[:endpoint] || '').handlePacket sessid, packet
    end
=begin
/**
 * Performs authentication.
 *
 * @param Object client request data
 * @api private
 */

Manager.prototype.authorize = function (data, fn) {
  if (this.get('authorization')) {
    var self = this;

    this.get('authorization').call(this, data, function (err, authorized) {
      self.log.debug('client ' + authorized ? 'authorized' : 'unauthorized');
      fn(err, authorized);
    });
  } else {
    this.log.debug('client authorized');
    fn(null, true);
  }

  return this;
};
=end
    def transports data
      (get 'transports').accept { | which |
        which and ( !which.checkClient or which.checkClient data )
      }
    end

=begin
/**
 * Checks whether a request is a socket.io one.
 *
 * @return {Object} a client request data object or `false`
 * @api private
 */

var regexp = /^\/([^\/]+)\/?([^\/]+)?\/?([^\/]+)?\/?$/

Manager.prototype.checkRequest = function (req) {
  var resource = this.get('resource');

  if (req.url.substr(0, resource.length) == resource) {
    var uri = url.parse(req.url.substr(resource.length), true)
      , path = uri.pathname || ''
      , pieces = path.match(regexp);

    // client request data
    var data = {
        query: uri.query || {}
      , headers: req.headers
      , request: req
      , path: path
    };

    if (pieces) {
      data.protocol = Number(pieces[1]);
      data.transport = pieces[2];
      data.id = pieces[3];
      data.static = !!Manager.static.paths[path];
    };

    return data;
  }

  return false;
};
=end
   def of nsp
     @namespaces[nsp] = SocketNamespace.new nsp unless @namespaces[nsp]
   end
end
