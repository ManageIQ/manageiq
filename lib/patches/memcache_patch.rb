class MemCache
  LARGE_VALUE_KEY = "***Oversized***"
  LARGE_VALUE_SIZE = 1_048_064 # Chose 512 bytes less than 1MB due to memcache's seemingly random max limit
  CHUNK_SIZE = 1_048_064

  alias_method :orig_get, :get

  ##
  # Retrieves +key+ from memcache.  If +raw+ is false, the value will be
  # unmarshalled.

  def get(key, raw = false)
    server, cache_key = request_setup(key)

    value = if @multithread
              threadsafe_cache_get(server, cache_key)
            else
              cache_get(server, cache_key)
            end

    return nil if value.nil?

    value = Marshal.load value unless raw
    value = cache_get_large(server, cache_key, value, raw) if large_value_key?(value)

    return value
  rescue TypeError, SocketError, SystemCallError, IOError => err
    handle_error(server, err)
  end

  ##
  # Shortcut to get a value from the cache.

  alias_method :[], :get

  alias_method :orig_set, :set

  ##
  # Add +key+ to the cache with value +value+ that expires in +expiry+
  # seconds.  If +raw+ is true, +value+ will not be Marshalled.
  #
  # Warning: Readers should not call this method in the event of a cache miss;
  # see MemCache#add.

  def set(key, value, expiry = 0, raw = false)
    raise MemCacheError, "Update of readonly cache" if @readonly
    server, cache_key = request_setup(key)
    socket = server.socket

    value = Marshal.dump(value) unless raw

    if value.length > LARGE_VALUE_SIZE
      cache_set_large(key, value, expiry)
    else
      command = "set #{cache_key} 0 #{expiry} #{value.size}\r\n#{value}\r\n"

      begin
        @mutex.lock if @multithread
        socket.write(command)
        result = socket.gets
        raise MemCacheError, $1.strip if result =~ /^SERVER_ERROR (.*)/
      rescue SocketError, SystemCallError, IOError => err
        socket.close
        raise MemCacheError, err.message
      ensure
        @mutex.unlock if @multithread
      end
    end
  end

  alias_method :orig_add, :add

  ##
  # Add +key+ to the cache with value +value+ that expires in +expiry+
  # seconds, but only if +key+ does not already exist in the cache.
  # If +raw+ is true, +value+ will not be Marshalled.
  #
  # Readers should call this method in the event of a cache miss, not
  # MemCache#set or MemCache#[]=.

  def add(key, value, expiry = 0, raw = false)
    raise MemCacheError, "Update of readonly cache" if @readonly
    server, cache_key = request_setup(key)
    socket = server.socket

    value = Marshal.dump(value) unless raw

    if value.length > LARGE_VALUE_SIZE
      cache_set_large(key, value, expiry)
    else
      command = "add #{cache_key} 0 #{expiry} #{value.size}\r\n#{value}\r\n"

      begin
        @mutex.lock if @multithread
        socket.write(command)
        socket.gets
      rescue SocketError, SystemCallError, IOError => err
        server.close
        raise MemCacheError, err.message
      ensure
        @mutex.unlock if @multithread
      end
    end
  end

  ##
  # Methods added to support large values

  def large_value_key?(key)
    key.kind_of?(String) && key[0, LARGE_VALUE_KEY.length] == LARGE_VALUE_KEY
  end

  def cache_get_large(server, cache_key, large_value_key, raw)
    # Handle recollecting a split object
    chunks = (0...large_value_key[LARGE_VALUE_KEY.length..-1].to_i).collect { |c| "#{cache_key}:chunk_#{c}" }
    chunks_keys = chunks.join(' ')
    values = if @multithread
               threadsafe_cache_get_multi(server, chunks_keys)
             else
               cache_get_multi(server, chunks_keys)
             end

    values = chunks.collect { |c| values[c] }
    return nil if values.include?(nil)

    value = values.join
    value = Marshal.load(value) unless raw
    value
  end

  def cache_set_large(key, value, expiry = 0)
    # Handle splitting this data into chunks
    chunks = []
    chunks << value.slice!(0...CHUNK_SIZE) until value.length == 0
    if chunks.length > 0
      set(key, "#{LARGE_VALUE_KEY}#{chunks.length}", expiry)
      chunks.each_with_index do |c, i|
        c_key = "#{key}:chunk_#{i}"
        set(c_key, c, expiry, true)
      end
    end
  end
end
