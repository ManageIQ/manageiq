class TokenStore
  module KeyValueHelpers
    def delete_all_for_user(userid)
      Array(read("tokens_for_#{userid}")).each do |token|
        delete(token)
      end

      delete("tokens_for_#{userid}")
    end

    def create_user_token(token, data, options)
      write(token, data, options)
    ensure
      if data[:userid]
        user_tokens_cache_key = "tokens_for_#{data[:userid]}"
        user_tokens_cache = read(user_tokens_cache_key) || []
        user_tokens_cache << token
        write(user_tokens_cache_key, user_tokens_cache)
      end
    end
  end

  def self.token_caches
    @token_caches ||= {} # Hash of Memory/Dalli Store Caches, Keyed by namespace
  end

  # only used by TokenManager.token_store
  # @return a token store for users
  def self.acquire(namespace, token_ttl)
    token_caches[namespace] ||= begin
      options = cache_store_options(namespace, token_ttl)
      case ::Settings.server.session_store
      when "sql"
        SqlStore.new(options)
      when "memory"
        require 'active_support/cache/memory_store'
        ActiveSupport::Cache::MemoryStore.new(options).tap do |store|
          store.extend KeyValueHelpers
        end
      when "cache"
        require 'active_support/cache/dalli_store'
        ActiveSupport::Cache::DalliStore.new(MiqMemcached.server_address, options).tap do |store|
          store.extend KeyValueHelpers
        end
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
