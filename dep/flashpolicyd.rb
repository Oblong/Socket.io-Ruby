#
# == Description
# This is a derivative work of flashpolicyd.  Original license, stated intent of 
# project, and author information is preserved as follows:
#
# -- start --
#
# == Synopsis
# flashpolicyd: Serve Adobe Flash Policy XML files to clients
#
# == Download and Further Information
# Latest versions, installation documentation and other related info can be found
# at http://code.google.com/p/flashpolicyd
#
# == License
# Released under the terms of the Apache 2 License, see the include COPYING file for full text of
# this license.
#
# == Author
# R.I.Pienaar <rip@devco.net>
#
# -- end --
#
# == Derivative Work Disclaimer
# All relevant priveleges, rights, and responsibilities for a derivative work as specified 
# in the license above are to be held by Oblong Industries Inc. (CA-US) for the work below. 
#
# The work below is directly derived from commit id e01ba4acb2a97b83d48510c8ad80e3688ff33049
# on https://github.com/ripienaar/flashpolicyd as pulled on July 15, 2011.
#
# The above notice takes effect in perpetuity as permitted, as of August 9, 2011.
#
# == Notes
# Human programmer is Chris Mckenzie <chris@oblong.com>.
#

require "socket"
require "logger"
require "ostruct"
require "thread"
require "timeout"

class PolicyServer
  include EventEmitter
  @@serverThread = nil

  # === Synopsis
  # Initializes the server
  #
  # === Args
  # +port+::
  #   The port to listen on, if the port is < 1024 server must run as roo
  # +host+::
  #   The host to listen on, use 0.0.0.0 for all addresses
  # +domains+::
  #   An array of the xdoms to support (defaults to '(*)')
  # +logger+::
  #   An instanse of the Ruby Standard Logger class
  # +timeout+::
  #   How long does client have to complete the whole process before the socket closes
  #   and the thread terminates
  def initialize(opts = {})
    {
      'port' => 10843,
      'maxclients' => 10,
      'host' => '0.0.0.0',
      'domains' => ['*'],
      'logger' => lambda { | x | puts x },
      'timeout' => 10
    }.each { | key, value |
      PolicyServer.class_eval("attr_reader :#{key}")
      instance_variable_set("@#{key}", opts[key] || value)
    }
    @port = @port.to_i

    @connections = []
    @@connMutex = Mutex.new
    @@clientsMutex = Mutex.new
    @@bogusclients = 0
    @@totalclients = 0
    @@starttime = Time.new

    @xml = <<-eos
      <?xml version="1.0"?>
      <!DOCTYPE cross-domain-policy SYSTEM "/xml/dtds/cross-domain-policy.dtd">
      <cross-domain-policy>
      <site-control permitted-cross-domain-policies="master-only"/>
    eos

    domains.each { | dom |
      @xml <<= '<allow-access-from domain="' + dom + '" to-ports="*" />'
    }

    @xml <<= '</cross-domain-policy>'

    start
  end

  def listen(ignored, &block)
    on('connect', &block)
  end

  # Generic logging method that takes a severity constant from the Logger class such as Logger::DEBUG
  def log(msg)
    @logger.call( "#{Thread.current.object_id}: #{msg}" )
  end

  # Returns an array of days, hrs, mins and seconds given a second figure
  # The Ruby Way - Page 227
  def sec2dhms(secs)
    time = secs.round
    sec = time % 60
    time /= 60

    mins = time % 60
    time /= 60

    hrs = time % 24
    time /= 24

    days = time
    [days, hrs, mins, sec]
  end

  # Walks the list of active connections and dump them to the logger at INFO level
  def dumpconnections
    if (@connections.size == 0)
      log("No active connections to dump")
    else
      connections = @connections

      log("Dumping current #{connections.size} connections:")

      connections.each{ |c|
        addr = c.addr
        log("#{c.thread.object_id} started at #{c.timecreated} currently in #{c.thread.status} status serving #{addr[2]} [#{addr[3]}]")
      }
    end
  end

  # Dump the current thread list
  def dumpthreads
    Thread.list.each do |t|
      log("Thread: #{t.id} status #{t.status}")
    end
  end

  # Prints some basic stats about the server so far, bogus client are ones that timeout or otherwise cause problems
  def printstats
    u = sec2dhms(Time.new - @@starttime)

    log("Had #{@@totalclients} clients and #{@@bogusclients} bogus clients. Uptime #{u[0]} days #{u[1]} hours #{u[2]} min. #{@connections.size} connection(s) in use now.")
  end

  # Logs a message passed to it and increment the bogus client counter inside a mutex
  def bogusclient(msg, client)
    addr = client.addr

    log("Client #{addr[2]} #{msg}")

    @@clientsMutex.synchronize {
      @@bogusclients += 1
    }
  end

  # The main logic of client handling, waits for @timeout seconds to receive a null terminated
  # request containing "policy-file-request" and sends back the data, else marks the client as
  # bogus and close the connection.
  #
  # Any exception caught during this should mark a client as bogus
  def serve(connection)
    emit('connect')
    client = connection.client

    # Flash clients send a null terminate request
    $/ = "\000"

    # run this in a timeout block, clients will have --timeout seconds to complete the transaction or go away
    begin
      timeout(@timeout.to_i) do
        loop do
          request = client.gets

          if request =~ /policy-file-request/
            client.puts(@xml)

            log("Sent xml data to client")
            break
          end
        end
      end
    rescue Timeout::Error
      bogusclient("connection timed out after #{@timeout} seconds", connection)
    rescue Errno::ENOTCONN => e
      log("Unexpected disconnection while handling request")
    rescue Errno::ECONNRESET => e
      log("Connection reset by peer")
    rescue Exception => e
      bogusclient("Unexpected #{e.class} exception: #{e}", connection)
    end
  end

  # === Synopsis
  # Starts the main loop of the server and handles connections, logic is more or less:
  #
  # 1. Opens the port for listening
  # 1. Create a new thread so the connection handling happens seperate from the main loop
  # 1. Create a loop to accept new sessions from the socket, each new sesison gets a new thread
  # 1. Increment the totalclient variable for stats handling
  # 1. Create a OpenStruct structure with detail about the current connection and put it in the @connections array
  # 1. Pass the connection to the serve method for handling
  # 1. Once handling completes, remove the connection from the active list and close the socket
  def start
    if @@serverThread.nil? 
      begin
        # Disable reverse lookups, makes it all slow down
        BasicSocket::do_not_reverse_lookup=true
        server = TCPServer.new(@host, @port)
      rescue Exception => e
        log("Can't open server: #{e.class} #{e}")
        return 
      end
    
      begin
        @@serverThread = Thread.new {
          while (session = server.accept)
            Thread.new(session) do |client|
              begin
                log("Handling new connection from #{client.peeraddr[2]}, #{Thread.list.size} total threads ")

                @@clientsMutex.synchronize {
                  @@totalclients += 1
                }

                connection = OpenStruct.new
                connection.client = client
                connection.timecreated = Time.new
                connection.thread = Thread.current
                connection.addr = client.peeraddr

                @@connMutex.synchronize {
                  @connections << connection
                  log("Pushed connection thread to @connections, now #{@connections.size} connections")
                }

                log("Calling serve on connection")
                serve(connection)

                client.close

                @@connMutex.synchronize {
                  @connections.delete(connection)
                  log("Removed connection from @connections, now #{@connections.size} connections")
                }

              rescue Errno::ENOTCONN => e
                log("Unexpected disconnection while handling request")
              rescue Errno::ECONNRESET => e
                log("Connection reset by peer")
              rescue Exception => e
                log("Unexpected #{e.class} exception while handling client connection: #{e}")
                log("Unexpected #{e.class} exception while handling client connection: #{e.backtrace.join("\n")}")
                client.close
              end # block around main logic
            end # while
          end # around Thread.new for client connections
        } # @serverThread
      rescue Exception => e
        log("Got #{e.class} exception in main listening thread: #{e}")
      end
    end
  end
end
