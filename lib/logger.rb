# socket.io-ruby
# Copyright(c) 2011 Oblong <chris@oblong.com>
# MIT Licensed
#
# Derived from
# socket.io-node
# Copyright(c) 2011 LearnBoost <dev@learnboost.com>
# MIT Licensed

module SocketIO
  class Logger
    attr_accessor :level

    def initialize(*args); end

    def write msg
      $stderr.puts msg
    end

    def error(*msg)
      write "Error: #{msg.join(' ')}"
    end

    def warn(*msg)
      write "Warn: #{msg.join(' ')}"
    end

    def info(*msg)
      write "Info: #{msg.join(' ')}"
    end

    def debug(*msg)
      write "Debug: #{msg.join(' ')}"
    end
  end
end
