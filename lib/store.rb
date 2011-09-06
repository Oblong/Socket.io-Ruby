# socket.io-ruby
# Copyright(c) 2011 Oblong <chris@oblong.com>
# MIT Licensed
#
# Derived from
# socket.io-node
# Copyright(c) 2011 LearnBoost <dev@learnboost.com>
# MIT Licensed

class Store
  # Store interface
  # 
  # @api public
  def initialize(options = nil) 
    @options = options
    @clients = {}
  end

  # Inherit from EventEmitter.
  include EventEmitter

  # Initializes a client store
  # 
  # @param [String] id
  # @api public
  def client id
    unless @clients[id].nil?
      @clients[id] = Store::Client.new self, id
    end

    @clients[id]
  end

  # Destroys a client
  # 
  # @api [String] sid
  # @param [FixNum] number of seconds to expire client data
  # @api private
  def destroyClient id, expiration
    if @clients[id]
      @clients[id].destroy expiration
      @clients.delete id
    end
  end

  # Destroys the store
  # 
  # @param [Number] number of seconds to expire client data
  # @api private
  def destroy clientExpiration
    @clients.each { | key, value |
      destroyClient value, clientExpiration
    }

    @clients = {}
  end

  alias :subscribe :on
  alias :publish :emit
  alias :unsubscribe :removeListener

  def getsession(&block); end
end

# Client.
# 
# @api public
class Client < Store
  attr_accessor :store, :id

  def initialize store, id
    @store = store
    @id = id
  end
end
