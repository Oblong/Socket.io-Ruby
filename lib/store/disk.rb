# socket.io-ruby
# Copyright(c) 2011 Oblong <chris@oblong.com>
# MIT Licensed
#
# Derived from
# socket.io-node
# Copyright(c) 2011 LearnBoost <dev@learnboost.com>
# MIT Licensed

# INSANELY SLOW ... but easy
class Disk < Store
  def initialize(*opts)
    @state = 'filedump'
    @oldData = {}
    @lastmod = nil
    File.open(@state, File::CREAT, 0666) 

    Thread.new {
      @lastmod = File.stat(@state)

      loop {
        if File.stat(@state) > @lastmod
          newdata load
          @lastmod = File.stat(@state)
        end

        sleep 0.1
      }
    }
  end

  def compare(old, nu, hash)
    @old.each do | key , value |
      if nu.has_key? key
        if nu[key] != value
          emit hash, key, nu[key]
        end
      else
        emit hash, key, nil
      end
    end

    nu.each do | key, value |
      unless @old.has_key? key
        emit hash, key, value
      end
    end
  end

  def newdata(nu)
    @oldData.each do | key , value |
      if nu.has_key? key
        if nu[key].kind_of? Hash
          compare value, nu[key], key
        elsif nu[key] != value
          emit key, nu[key]
        end
      else
        emit key, nil
      end
    end

    nu.each do | key, value |
      unless @oldData.has_key? key
        if value.kind_of? Hash
          value.each do | _key, _value |
            emit key, _key, _value
          end
        else
          emit key, value
        end
      end
    end

    @oldData = nu
  end 

  def load
    begin
      File.open(@state) do | file |
        Marshal.load(file)
      end
    rescue
      return {}
    end
  end

  def save(data)
    File.open(@state, 'w') do | file |
      $stderr.puts YAML.dump(data)
      Marshal.dump(data, file)
    end
  end

  def publish(key, *args)
     data = load
     if(args.length == 2) 
       data[key] ||= {}
       data[key][args[0]] = args[1]
     else
       data[key] = args
     end
     save data
  end
end
