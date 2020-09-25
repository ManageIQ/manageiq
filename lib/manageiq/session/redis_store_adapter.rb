module ManageIQ
  module Session
    class RedisStoreAdapter < AbstractStoreAdapter
      def type
        :redis_store
      end

      def session_options
        opts = super
        opts.merge(
          :servers      => ::Settings.session.redis_url,
          :expire_after => 24.hours,
          :key          => "_vmdb_session"
        )
      end
    end
  end
end
