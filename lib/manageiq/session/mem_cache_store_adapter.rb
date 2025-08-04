module ManageIQ
  module Session
    class MemCacheStoreAdapter < AbstractStoreAdapter
      def type
        :mem_cache_store
      end

      def session_options
        require 'miq_memcached'
        super.merge(MiqMemcached.default_client_options).merge(
          :expire_after    => 24.hours,
          :key             => "_vmdb_session",
          :memcache_server => MiqMemcached.server_address,
          :namespace       => "MIQ:VMDB",
          :pool_size       => 10,
          :value_max_bytes => 10.megabytes
        )
      end

      def enable_rack_session_debug_logger
        return if Rails.env.production?

        puts "** Enabling rack session debug logger"
        rack_session_class_to_prepend.prepend(ManageIQ::Session::RackSessionDalliLogger)
      end

      def rack_session_class_to_prepend
        require 'rack/session/dalli'
        ::Rack::Session::Dalli
      end
    end
  end
end
