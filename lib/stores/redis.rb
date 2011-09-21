# socket.io-ruby
# Copyright(c) 2011 Oblong <chris@oblong.com>
# MIT Licensed
#
# Derived from
# socket.io-node
# Copyright(c) 2011 LearnBoost <dev@learnboost.com>
# MIT Licensed


# Redis store.
# Options:
#     - nodeId (fn) gets an id that uniquely identifies this node
#     - redis (fn) redis constructor, defaults to redis
#     - redisPub (object) options to pass to the pub redis client
#     - redisSub (object) options to pass to the sub redis client
#     - redisClient (object) options to pass to the general redis client
#     - pack (fn) custom packing, defaults to JSON or msgpack if installed
#     - unpack (fn) custom packing, defaults to JSON or msgpack if installed
#
# @api public
class Redis < Store

  include EventEmitter
  def initialize(opts = {})
    opts ||= {}

    # node id to uniquely identify this node
    # by default, we generate a random id 
    @nodeId = opts.nodeId || UUID.generate.hex

    # packing / unpacking mechanism
    # You can't alias things like this in ruby
    if not opts.pack.nil?
      @pack = opts.pack
      @unpack = opts.unpack
    else
      begin
        msgpack = require('msgpack')
        @pack = msgpack.pack
        @unpack = msgpack.unpack
      rescue
        @pack = JSON.stringify
        @unpack = JSON.parse
      end
    end

    redis = opts.redis || require('redis')
    RedisClient = redis.RedisClient

    # initialize a pubsub client and a regular client
    if (opts.redisPub.class == RedisClient)
      @pub = opts.redisPub
    else
      opts.redisPub ||= {}
      @pub = redis.createClient(opts.redisPub.port, opts.redisPub.host, opts.redisPub)
    end

    if (opts.redisSub.class == RedisClient)
      @sub = opts.redisSub
    else
      opts.redisSub ||= {}
      @sub = redis.createClient(opts.redisSub.port, opts.redisSub.host, opts.redisSub)
    end
    if (opts.redisClient.class == RedisClient)
      @cmd = opts.redisClient
    else
      opts.redisClient ||= {}
      @cmd = redis.createClient(opts.redisClient.port, opts.redisClient.host, opts.redisClient)
    end

    super
  end

  # Publishes a message.
  #
  # @api private

  def publish(*args)
    @pub.publish(args[0], @pack({ 
      'nodeId' => @nodeId, 
      'args' => args })
    )
    @emit.call(['publish', args[0]].concat(args))
  end

  # Subscribes to a channel
  #
  # @api private
  def subscribe(name, consumer, fn = nil)
    @sub.subscribe(name)

    if (consumer or not fn.nil?)
      subscribe = @sub.on('subscribe') do | ch |
        if (name == ch)
          def message (ch, msg)
            if (name == ch)
              msg = self.unpack(msg)

              # we check that the message consumed wasnt emitted by this node
              if (self.nodeId != msg.nodeId)
                consumer.apply(null, msg.args)
              end
            end
          end

          @sub.on('message', message)

          unsubscribe = on('unsubscribe') do | ch |
            if (name == ch)
              @sub.removeListener('message', message)
              removeListener('unsubscribe', unsubscribe)
            end
          end

          @sub.removeListener('subscribe', subscribe)

          fn && fn()
        end
      end
    end

    @emit('subscribe', name, consumer, fn)
  end

  # Unsubscribes
  #
  # @api private
  def unsubscribe (name, fn)
    @sub.unsubscribe(name)

    if (fn)
      client = @sub

      client.on('unsubscribe') do | ch |
        if (name == ch)
          fn()
          client.removeListener('unsubscribe', unsubscribe)
        end
      end
    end

    @emit('unsubscribe', name, fn)
  end

  # Destroys the store
  #
  # @api public
  def destroy ()
    super

    @pub.doEnd
    @sub.doEnd
    @cmd.doEnd
  end
end

module Redis < Store::Client
  include EventEmitter
  # Client constructor
  #
  # @api private
  class Client(store, id)
    super
  end

  # Redis hash get
  #
  # @api private
  def get(key, fn)
    @store.cmd.hget(@id, key, fn)
  end

  # Redis hash set
  #
  # @api private
  def set(key, value, fn)
    @store.cmd.hset(@id, key, value, fn)
  end

  # Redis hash del
  #
  # @api private
  def del(key, fn)
    @store.cmd.hdel(@id, key, fn)
  end

  # Redis hash has
  #
  # @api private
  def has(key, fn)
    @store.cmd.hexists(@id, key) do |err, has|
      if (err) return fn(err)
      fn(null, !!has)
    end
  end

  # Destroys client
  #
  # @param {Number} number of seconds to expire data
  # @api private
  def destroy(expiration)
    if (expiration.class == FixNum)
      @store.cmd.del(@id)
    else
      @store.cmd.expire(@id, expiration)
    end
  end
end
