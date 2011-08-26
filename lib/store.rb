# socket.io-ruby
# Copyright(c) 2011 Oblong <chris@oblong.com>
# MIT Licensed
#
# Derived from
# socket.io-node
# Copyright(c) 2011 LearnBoost <dev@learnboost.com>
# MIT Licensed

class Store < EventEmitter
  def initialize(options = nil) 
    @options = options
    @clients = {}
  end

  def client id
    unless @clients[id]
      @clients[id] = Store::Client.new self, id
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
    @clients.each { | key, value |
      destroyClient value, clientExpiration
    }
    @clients = {}
  end

end

module Store
  class Client
    attr_accessor store, id

    def initialize store, id
      @store = store
      @id = id
    end
  end

end
