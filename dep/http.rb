# node.js like HTTP module for ruby
# Copyright(c) 2011 Oblong <chris@oblong.com>
# MIT Licensed

require 'EventEmitter'
require 'thread'
# require 'yaml'

Thread.abort_on_exception = true
#
# Implemented based on documentation from http://nodejs.org/docs/v0.5.0/api/http.html
# Quotations are used wherein relevant
#

module HTTP
  attr_reader :agent

  def self.createServer(&requestListener)
    @@serverInstance
  end

  def self.server
    @@serverInstance
  end

  class Server
    include EventEmitter
    def initialize; end
    def listen(port, fn)
    end
  end

  @@serverInstance = Server.new

  #
  # We need
  # end, close, error, drain
  class Socket
    include EventEmitter
    def initialize; end
  end

  class FromRack
    def initialize(app, options = {})
      @app = app
      @threadMap = {}
      @paths = []

      options.each { | key, value |
        instance_variable_set("@#{key}", value)
      }
    end

    def each 
      loop {
        data = @response.body.pop 
        if data.nil?
          break
        else
          yield data
        end
      } 

      @request.socket.emit('drain')
      @request.socket.emit('end')
      HTTP::server.emit('close')
      @request.socket.emit('close')
    end

    def call env
      matched = false 
      @paths.each do | path |
        matched |= (env['PATH_INFO'][0..path.length - 1] == path)
      end

      unless matched
        return @app.call(env) if @app and @app.respond_to? :call
      end


      httpHeaders = env.reject{ | key, value | key.class != String || key[0..3] != 'HTTP' }
      pairwise = {}

      httpHeaders.each { | key, value | 
        string = key.downcase.gsub('_', ' ')[5..-1].split(' ').map { | x | x.capitalize }
        string = string.join('-')

        pairwise[ string ] = value 
      }

      @request = ServerRequest.new({
        'method' => env['REQUEST_METHOD'],
        'url' => env['REQUEST_URI'],
        'headers' => pairwise,
        'threadMap' => @threadMap,
        'socket' => Socket.new,
        'connection' => {
          'remoteAddress' => env['REMOTE_ADDR'],

          # These are faked, coerced values
          'secure' => false,
          'remotePort' => '9292'
        }
      })

      # We have to make sure that this is called after the app thread starts
      # and doesn't just start emitting events prior to it running
      @request.threadMap['request.data'] = @threadMap['request.data'] = Thread.new {
        Thread.stop

        unless env['rack.input'].nil?
          env['rack.input'].each do | data |
            @request.emit('data', data)
          end
        end

        @request.emit('end')
      }

      # if we block on the header writing code and then
      # yield when it exits, we can achieve the documented
      # results
      @threadMap['response.header'] = Thread.new {
        loop {
          sleep 2
        }
      }

      @response = ServerResponse.new 'threadMap' => @threadMap 

      # Although not documented on the site, socket.io in
      # lib/transports/http.js HTTPTransport.prototype.handleRequest (0.7.9)
      # appears to assume that this variable exists. So we put it
      # here to make it happy.
      @request.res = @response

      # Now the request and the response has been created
      # we can call the app that will handle the functions
      # in a new thread
      @threadMap['app'] = Thread.new {

        # This is probably still insufficient placement
        HTTP::server.emit('request', @request, @response) 

        @request.threadMap['request.data'].run
      }
      @threadMap['response.header'].join

      # If the above thread is run, then we can return with
      # the headers + the yield for the call
      status, header = @response.headerFull

      [ status, header, self ]
    end
  end

  class ServerRequest
    include EventEmitter

    attr_accessor :method, :url, :headers, :trailers, :httpVersion, :connection, :threadMap, :res, :socket

    def [](key)
      @data[key]
    end

    def []=(key, value)
      @data[key] = value
    end

    def initialize(options = {})
      @trailers = nil
      @data = {}
      @connection = nil
      @encoding = nil

      options.each { | key, value |
        instance_variable_set("@#{key}", value)
      }
    end

    def setEncoding(encoding = nil)
      @encoding = encoding
    end

    def pause
      @threadMap['request.data'].stop if @threadMap['request.data'].status == 'run'
    end

    def resume
      @threadMap['request.data'].run if @threadMap['request.data'].status == 'sleep'
    end
  end

  class ServerResponse
    include EventEmitter

    attr_reader :statusCode, :headerFull, :body

    def initialize(options = {})
      @headerFull = ''
      @data = {}
      @headerMap = {
        'Content-Type' => 'text/plain'
      }
      @statusCode = 200
      @body = Queue.new

      options.each { | key, value |
        instance_variable_set("@#{key}", value)
      }
    end

    def [](key)
      @data[key]
    end

    def []=(key, value)
      @data[key] = value
    end

    def writeContinue
      raise NotImplementedError
    end

    # This doesn't hit the wire until the total response
    #
    #   "The last argument, headers, are the response headers. 
    #    Optionally one can give a human-readable reasonPhrase 
    #    as the second argument."
    #
    def writeHead(*args) #statusCode, reasonPhrase = nil, headers = nil )
      if args.length > 0

        # It looks like that if writeHead is passed with one argument,
        # then it defaults to the status code
        #
        # As a convenience we typecast it to an int, just to try to
        # appease rack
        @statusCode = (args.shift)

        # With the remainder going here if necessry
        if args.length > 0
          headers = args.pop
          # First take the end
          unless headers.nil?
            headers.each { | key, value|
              @headerMap[key] = value
            }
          end
        end

        # If there is anything left, use that
        # reasonPhrase = args[0] if args.length
      end

      # Rack::Lint::LintError: Content-Type header found in 304 response, not allowed
      if @statusCode.to_i == 304 and @headerMap.has_key? 'Content-Type'
        @headerMap.delete 'Content-Type'
      end

      # Type casting appears to be important to Rack
      @headerMap.each { | key, value | 
        @headerMap[key] = value.to_s
      }

      @headerFull = [ @statusCode, @headerMap ]

      if @threadMap['response.header'].status.class == String 
        Thread.kill @threadMap['response.header'] 
      end
    end

    def setHeader(name, value)
      @headerMap[name] = value
    end

    def getHeader(name)
      @headerMap[name]
    end

    def removeHeader(name)
      @headerMap.delete name if @headerMap.has_key? name
    end

    def write(chunk, encoding = 'utf8')
      #  "If this method is called and 
      #   response.writeHead() has not been 
      #   called, it will switch to implicit 
      #   header mode and flush the implicit 
      #   headers."
      writeHead

      @body << chunk
    end

    def addTrailers(headers = {})
      raise NotImplementedError
    end

    def doEnd(data = nil, encoding = nil)
      #  "If data is specified, it is equivalent to 
      #   calling response.write(data, encoding) 
      #   followed by response.end()."
      write(data, encoding) unless data.nil?
      begin
        # raise Exception
      rescue Exception => e
        puts e.backtrace
      end
      @body << nil
    end
  end

  def self.request(options = {}, &callback)
    raise NotImplementedError
  end

  def self.get(options = {}, &callback)
    raise NotImplementedError
  end

  def self.getAgent(options = {})
    raise NotImplementedError
  end

  class ClientRequest
    def initialize; end

    def write(chunk, encoding = 'utf8')
      raise NotImplementedError
    end

    def doEnd(data = nil, encoding = nil)
      #  "If data is specified, it is equivalent to 
      #   calling request.write(data, encoding) 
      #   followed by request.end()."
      write(data, encoding) unless data.nil?
      raise NotImplementedError
    end

    def abort
      raise NotImplementedError
    end
  end

  class ClientResponse
    attr_accessor :statusCode, :httpVersion, :headers, :trailers

    #  "Also response.httpVersionMajor is the 
    #   first integer and response.httpVersionMinor 
    #   is the second."
    attr_reader :httpVersionMajor, :httpVersionMinor

    def initialize

      # Note: we are just using 1.1 for now.
      @httpVersionMinor = 1
      @httpVersionMajor = 1

      @httpVersion = "#{@httpVersionMajor}.#{@httpVersionMinor}"
    end

    def setEncoding(encoding = nil)
      @encoding = encoding
    end

    def pause
      raise NotImplementedError
    end

    def resume
      raise NotImplementedError
    end
  end
end
