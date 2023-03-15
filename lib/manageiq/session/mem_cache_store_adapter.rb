module ManageIQ
  module Session
    class MemCacheStoreAdapter < AbstractStoreAdapter
      def type
        :mem_cache_store
      end

      def session_options
        super.merge(MiqMemcached.default_client_options).merge(
          :expire_after    => 24.hours,
          :key             => "_vmdb_session",
          :memcache_server => MiqMemcached.server_address,
          :namespace       => "MIQ:VMDB",
          :pool_size       => 10,
          :value_max_bytes => 10.megabytes
        )
      end
    end
  end
end
