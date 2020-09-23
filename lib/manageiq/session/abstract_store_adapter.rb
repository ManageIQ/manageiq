module ManageIQ
  module Session
    class AbstractStoreAdapter
      def session_options
        session_options = {}

        if MiqEnvironment::Command.is_appliance?
          session_options[:secure]   = true unless ENV["ALLOW_INSECURE_SESSION"]
          session_options[:httponly] = true
        end

        session_options
      end

      def session_store_config_args
        [type, session_options]
      end
    end
  end
end
