class TokenStore
  @token_caches = {} # Hash of Memory/Dalli Store Caches, Keyed by namespace

  def self.acquire(namespace, token_ttl)
    @token_caches[namespace] ||= begin
      case ::Settings.server.session_store
      when "sql"
        SqlStore.new(cache_store_options(namespace, token_ttl))
      when "memory"
        require 'active_support/cache/memory_store'
        ActiveSupport::Cache::MemoryStore.new(cache_store_options(namespace, token_ttl))
      when "cache"
        require 'active_support/cache/dalli_store'
        memcache_server = ::Settings.session.memcache_server
        ActiveSupport::Cache::DalliStore.new(memcache_server, cache_store_options(namespace, token_ttl))
      else
        raise "unsupported session store type: #{::Settings.server.session_store}"
      end
    end
  end

  def self.cache_store_options(namespace, token_ttl)
    {
      :namespace  => "MIQ:TOKENS:#{namespace.upcase}",
      :threadsafe => true,
      :expires_in => token_ttl
    }
  end
  private_class_method :cache_store_options
end
