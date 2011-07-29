class Store < EventEmitter
  def initialize(options = nil) 
    @options = options
    @clients = {}
  end

  def client id
    unless @clients[id]
      #TODO 
      @clients[id] = new (this.constructor.Client)(this, id);
    end

    @clients[id]
  end

  def destroyClient id, expiration
    if @clients[id]
      @clients[id].destroy expiration
      @clients.delete id
    end
  end

  def destroy clientExpiration
    #TODO

=begin
Store.prototype.destroy = function (clientExpiration) {
  var keys = Object.keys(this.clients)
    , count = keys.length;

  for (var i = 0, l = count; i < l; i++) {
    this.destroyClient(keys[i], clientExpiration);
  }

=end
    @clients = {}
  end

  def client store, id
    @store = store
    @id = id
  end
end
