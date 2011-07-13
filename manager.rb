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
end
