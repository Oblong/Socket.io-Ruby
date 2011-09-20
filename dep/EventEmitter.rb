# EventEmitter-ruby
# Copyright(c) 2011 Oblong <chris@oblong.com>
# MIT Licensed
require 'rubygems'
require 'eventmachine'

module EventEmitter
  @_queue = nil
  class Broadcast < EventMachine::Connection
    def post_init
      $stderr.puts "Connection Up"
    end

    # All it does is echo data in back out
    # to all the listeners
    def receive_data(data)
      $stderr.puts YAML.dump(data)
      send_data data
    end
  end


  def self.start
    # The server will delegate messages amongst
    # the various threads.  This is only ran once.
    thread = Thread.new do
      EventMachine::run do
        EventMachine::start_server '0.0.0.0', 5000, EventEmitter::Broadcast
      end
    end
  end

  # Each mixin has a listener to the Broadcast server
  # It will be instantiated by _queue as a singleton below.
  class Receiver < EventMachine::Connection
    def initialize(param)
      # The messages across the threads are keyed by
      # the thread id, the class name, and the payload
      # itself.
      @thread = param[0]
      @class = param[1]
      @queue = param[2]

      $stderr.puts "Receiver up"
      # This is run whenever we push data onto
      # the thread from our emit calls below.
      #
      # This will then be sent to the broadcaster above
      # which will then go out to all the listeners
      Thread.new {
        loop {
          data = @queue.pop
          send_data [@thread, @class, data]
        }
      }
    end

    # The listener receives the data and then breaks
    # down the payload to the thread id that put the 
    # data in there, the class name of the object
    # and the payload itself.
    def receive_data(data)
      thread = data[0]
      klass = data[1]
      payload = data[2]

      # It makes sure that it wasn't the emitter of
      # the payload to avoid eating a message twice.
      #
      # It also sees if this class is specific to it'
      # message
      if thread != @thread and klass == @class
        emit(*payload)
      end
    end
  end

  def _queue
    if @_queue.nil?
      @_queue = Queue.new

      id = Thread.current
      klass = self.class.to_s

      Thread.new {
        EventMachine.run {
          EventMachine.connect '0.0.0.0', 5000, Receiver, [id, klass, @_queue]
        }
      } 
    end
    @_queue
  end

  def listeners(event = nil)
    (_get event).map do | which | 
      @registrar[which] 
    end
  end

  def on(event, &function)
    emit('newListener', [event, function])
    @registrar_index += 1
    @registrar[@registrar_index] = function
    (_get event) << @registrar_index
    @registrar_index
  end

  def once(event, &function)
    id = on(event) do |*args|
      function.call(*args)
      removeListener(event, id) 
    end 
  end

  def setMaxListeners(n); end

  alias addListener on

  def removeListener(event, function)
    if function.class == Fixnum
      _get(event).reject! do | handle | 
        handle == function 
      end
    else
      _get(event).reject! do | handle | 
        @registrar[handle] == function
      end
    end
  end

  def removeAllListeners(event)
    _get(event).each do | index |
      @registrar.delete index
    end 

    _get(event).clear
  end

  def emit(event, *args)
    _get(event).each do | index |
      @registrar[index].call(*args)
    end 

    _queue.push( [event, *args].flatten )
  end

  # Duplication because socket.io likes
  # to override the emit
  def _emit(event, *args)
    _get(event).each do | index |
      @registrar[index].call(*args)
    end 

    _queue << [event, *args].flatten
  end

  private

  def _get(event = nil)
    # This is needed for once, unless
    # you have a better idea how to 
    # implement it
    @registrar ||= {}
    @registrar_index ||= 1

    @cbMap ||= {}
    @cbMap[event] ||= []
  end
end

