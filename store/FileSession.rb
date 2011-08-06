class FileSession < Store

  def initialize(file)
    @file = file
    @lock = file + '.lock'
  end
    
  def getsession(&block)
    ret = nil
    store = nil
    File.open(@lock, File::CREAT, 0666) do |lock|
      # lock the file
      lock.flock File::LOCK_EX

      if File.exist?(@file)
        store = YAML.load_file(@file)
      end

      unless store.is_a?(Hash)
        store = {}
      end

      # call the modifier or retriever
      ret = block.call(store)

      File.open(@file, File::CREAT|File::TRUNC|File::WRONLY, 0666) do |file|
        # write the whole data
        YAML.dump(store, file)
      end

      # release the lock
      lock.flock File::LOCK_UN
    end
    ret
  end

  def dump()
    getsession { |store| store }
  end

  def get(key)
    getsession { |store| store[key] }
  end

  def hashget(key, value)
    getsession { |store| store[key][value] }
  end

  def set(key, value)
    getsession { |store| store[key] = value }
  end

  def del(key)
    getsession do |store|
      if store.has_key?(key) 
        store.delete(key)
      end
    end
  end

  def decr(key)
    getsession do |store| 
      if store.has_key? key and store[key].is_a?(Number)
        store[key] -= 1
      else
        store[key] = 0
      end
    end
  end

  def incr(key)
    ret = ''
    getsession do |store| 
      if store.has_key? key and store[key].is_a?(Number)
        store[key] += 1
      else
        store[key] = 1
      end
      ret = store[key]
    end
    ret
  end

  def hashdel(key, value)
    getsession do |store|
      if store.has_key?(key) and store[key].is_a?(Hash) and store[key].has_key?(value)
        store[key].delete(value)
      end
    end
  end

  def hashset(key, value1, value2)
    getsession do |store|
      unless store.has_key?(key) and store[key].is_a?(Hash)
        store[key] = {}
      end
      store[key][value1] = value2
    end
  end

  # append a value to an array
  def append(key, value)
    getsession do |store|
      unless store.has_key?(key) and store[key].is_a?(Array)
        store[key] = []
      end
      store[key].push(value)
    end
  end

  # remove a value from an array
  def unappend(key, value)
    getsession do |store|
      store[key].delete_if do | x |
        x == value
      end
    end
  end
end
