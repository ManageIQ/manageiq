require "extensions/rack_session_dalli_patch"

module ManageIQ
  module Session
    class MemCacheStoreAdapter < AbstractStoreAdapter
      def type
        :mem_cache_store
      end

      def session_options
        opts  = super
        cache = Dalli::Client.new(MiqMemcached.server_address, :namespace => "MIQ:VMDB", :value_max_bytes => 10.megabytes)
        opts.merge(
          :cache        => cache,
          :expire_after => 24.hours,
          :key          => "_vmdb_session"
        )
      end
    end
  end
end
