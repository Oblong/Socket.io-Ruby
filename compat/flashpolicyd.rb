# == Synopsis
#
# flashpolicyd: Serve Adobe Flash Policy XML files to clients
#
# == Description
# Server to serve up flash policy xml files for flash clients since
# player version 9,0,124,0. (Player 9 update 3)
#
# See http://www.adobe.com/devnet/flashplayer/articles/fplayer9_security_04.html
# for more information, this needs to run as root since it should listen on
# port 843 which on a unix machine needs root to listen on that socket.
#
# == Signals
# * USR1 signal prints a single line stat message, during
#   normal running this stat will be printed every 30 minutes by default, settable
#   using --logfreq
# * USR2 signal dumps the current threads and their statusses
# * HUP signal will toggle debug mode which will print more lines in the log file
# * TERM signal will exit the process closing all the sockets
#
# == Usage
# flashpolicyd [OPTIONS]
#
# xml
#   XML data to Serve to clients
#
# --timeout, -t
#   If a request does not complete within this time, close the socket,
#   default is 10 seconds
#
# --logfreq, -l
#   How often to log stats to log file, default 1800 seconds
#
# --logfile
#   Where to write log lines too
#
# --user
#   Drops privileges after binding to the socket to this user
#
# --port
#   What port to listen on 843 by default
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
# Oblong 

require "socket"
require "logger"
require "ostruct"
require "thread"
require "timeout"

module FlashPolicy
  class << self
    include EventEmitter

    def xml=(data)
      @server.xml = data
    end

    def initialize(options, origins)

      # defaults before parsing command line
      @timeout = 10
      @logfreq = 1800
      @port = 843
      @daemonize = true
      xmlfile = ""
      logfile = ""
      user = ""

      options.each { |opt, arg|
        case opt
          when 'xml'
            xmlfile = arg
          when 'user'
            user = arg
          when 'maxclients'
            @maxclients = arg
          when 'logfreq'
            @logfreq = arg
          when 'timeout'
            @timeout = arg
          when 'port'
            @port = arg.to_i
          when 'log'
            logfile = arg
        end
      }

      # create a logger keeping 10 files of 1MB each
      begin
        @logger = Logger.new(logfile, 10, 102400)
      rescue Exception => e
        puts("Got #{e.class} #{e} while attempting to create logfile #{logfile}")
        exit
      end
    end

    def run_server
      fork do
        exit if fork
        yield
      end
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

    # Go into the background and initalizes the server, sets up some signal handlers and print stats
    # every @logfreq seconds, any exceptions gets logged and exits the server
    run_server do
      begin
        @logger.info("Starting server on port #{@port} in process #{$$}")

        @server = PolicyServer.new({
          'port' => @port, 
          'host' => "0.0.0.0", 
          'log' => @logger, 
          'timeout' => @timeout
        })
        server.start

       # change user after binding to port
       if user.length > 0
          require 'etc'
          uid = Etc.getpwnam(user).uid
          gid = Etc.getpwnam(user).gid
          # Change process ownership
          Process.initgroups(user, gid)
          Process::GID.change_privilege(gid)
          Process::UID.change_privilege(uid)
        end


        # Cycle and print stats every now and then
        loop do
          sleep @logfreq.to_i
          server.printstats
        end
      rescue SystemExit => e
        @logger.fatal("Shutting down main daemon thread due to: #{e.class} #{e}")
      rescue Exception => e
        @logger.fatal("Unexpected exception #{e.class} from main loop: #{e}")
        @logger.fatal("Unexpected exception #{e.class} from main loop: #{e.backtrace.join("\n")}")
      end

      @logger.info("Server process #{$$} shutting down")
    end
  end

  class PolicyServer
    attr_accessor :xml

    # Generic logging method that takes a severity constant from the Logger class such as Logger::DEBUG
    def log(severity, msg)
      @logger.add(severity) { "#{Thread.current.object_id}: #{msg}" }
    end

    # Log a msg at level INFO
    def info(msg)
      log(Logger::INFO, msg)
    end

    # Log a msg at level WARN
    def warn(msg)
      log(Logger::WARN, msg)
    end

    # Log a msg at level DEBUG
    def debug(msg)
      log(Logger::DEBUG, msg)
    end

    # Log a msg at level FATAL
    def fatal(msg)
      log(Logger::FATAL, msg)
    end

    # Log a msg at level ERROR
    def error(msg)
      log(Logger::ERROR, msg)
    end

    # === Synopsis
    # Initializes the server
    #
    # === Args
    # +port+::
    #   The port to listen on, if the port is < 1024 server must run as roo
    # +host+::
    #   The host to listen on, use 0.0.0.0 for all addresses
    # +xml+::
    #   The XML to serve to clients
    # +logger+::
    #   An instanse of the Ruby Standard Logger class
    # +timeout+::
    #   How long does client have to complete the whole process before the socket closes
    #   and the thread terminates
    def initialize(opts)
      {
        'port' => 7788,
        'host' => '0.0.0.0',
        'xml' => nil,
        'logger' => false,
        'timeout' => 10
      }.each { | key, value |
        instance_variable_set("@#{key}", opts[key] || value)
      }

      @connections = []
      @@connMutex = Mutex.new
      @@clientsMutex = Mutex.new
      @@bogusclients = 0
      @@totalclients = 0
      @@starttime = Time.new

      @logger.level = Logger::DEBUG
    end

    # Walks the list of active connections and dump them to the logger at INFO level
    def dumpconnections
      if (@connections.size == 0)
        info("No active connections to dump")
      else
        connections = @connections

        info("Dumping current #{connections.size} connections:")

        connections.each{ |c|
          addr = c.addr
          info("#{c.thread.object_id} started at #{c.timecreated} currently in #{c.thread.status} status serving #{addr[2]} [#{addr[3]}]")
        }
      end
    end

    # Dump the current thread list
    def dumpthreads
      Thread.list.each {|t|
        info("Thread: #{t.id} status #{t.status}")
      }
    end

    # Prints some basic stats about the server so far, bogus client are ones that timeout or otherwise cause problems
    def printstats
      u = sec2dhms(Time.new - @@starttime)

      info("Had #{@@totalclients} clients and #{@@bogusclients} bogus clients. Uptime #{u[0]} days #{u[1]} hours #{u[2]} min. #{@connections.size} connection(s) in use now.")
    end

    # Logs a message passed to it and increment the bogus client counter inside a mutex
    def bogusclient(msg, client)
      addr = client.addr

      warn("Client #{addr[2]} #{msg}")

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

              debug("Sent xml data to client")
              break
            end
          end
        end
      rescue Timeout::Error
        bogusclient("connection timed out after #{@timeout} seconds", connection)
      rescue Errno::ENOTCONN => e
        warn("Unexpected disconnection while handling request")
      rescue Errno::ECONNRESET => e
        warn("Connection reset by peer")
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
      begin
        # Disable reverse lookups, makes it all slow down
        BasicSocket::do_not_reverse_lookup=true
        server = TCPServer.new(@host, @port)
      rescue Exception => e
        fatal("Can't open server: #{e.class} #{e}")
        exit
      end

      begin
        @serverThread = Thread.new {
          while (session = server.accept)
            Thread.new(session) do |client|
              begin
                debug("Handling new connection from #{client.peeraddr[2]}, #{Thread.list.size} total threads ")

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
                  debug("Pushed connection thread to @connections, now #{@connections.size} connections")
                }

                debug("Calling serve on connection")
                serve(connection)

                client.close

                @@connMutex.synchronize {
                  @connections.delete(connection)
                  debug("Removed connection from @connections, now #{@connections.size} connections")
                }

              rescue Errno::ENOTCONN => e
                warn("Unexpected disconnection while handling request")
              rescue Errno::ECONNRESET => e
                warn("Connection reset by peer")
              rescue Exception => e
                error("Unexpected #{e.class} exception while handling client connection: #{e}")
                error("Unexpected #{e.class} exception while handling client connection: #{e.backtrace.join("\n")}")
                client.close
              end # block around main logic
            end # while
          end # around Thread.new for client connections
        } # @serverThread
      rescue Exception => e
        fatal("Got #{e.class} exception in main listening thread: #{e}")
      end
    end
  end

end
