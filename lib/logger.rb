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

    def write type, msg
      toPrint = [type]

      msg.each do | key | 
        if key.class == String
          toPrint << key
        else
          toPrint << YAML.dump(key)
        end
      end 

      $stdout.puts '[' + Process.pid.to_s + ']: ' + toPrint.join(' ')
    end

    def error(*msg)
      write "Error:", msg
    end

    def warn(*msg)
      write "Warn:", msg
    end

    def info(*msg)
      write "Info:", msg
    end

    def debug(*msg)
      write "Debug:", msg
    end
  end
end
