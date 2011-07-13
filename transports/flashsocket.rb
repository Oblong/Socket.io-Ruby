module Transports
  class FlashSocket < Transports::WebSocket
    def initialize(mng, data, req)
      super(mng, data, req)
      @name = 'flashsocket'
=begin
  function create () {
    server = require('policyfile').createServer({ 
      log: function(msg){
        manager.log.info(msg.toLowerCase());
      }
    }, manager.get('origins'));

    server.on('close', function (e) {
      server = null;
    });

    server.listen(manager.get('flash policy port'), manager.server);

    manager.flashPolicyServer = server;
  }

  // listen for origin changes, so we can update the server
  manager.on('set:origins', function (value, key) {
    if (!server) return;

    // update the origins and compile a new response buffer
    server.origins = Array.isArray(value) ? value : [value];
    server.compile();
  });

  // destory the server and create a new server
  manager.on('set:flash policy port', function (value, key) {
    var transports = manager.get('transports');

    if (server && server.port !== value && ~transports.indexOf('flashsocket')) {
      // destroy the server and rebuild it on a new port
      server.close();
      create();
    }
  });

  // only start the server
  manager.on('set:transports', function (value, key){
    if (!server && ~manager.get('transports').indexOf('flashsocket')) {
      create();
    }
  });

  // check if we need to initialize at start
  if (~manager.get('transports').indexOf('flashsocket')){
    create();
  }
=end
    end
  end
end
