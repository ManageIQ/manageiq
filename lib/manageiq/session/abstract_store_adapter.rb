module ManageIQ
  module Session
    class AbstractStoreAdapter
      def session_options
        session_options = {}

        if MiqEnvironment::Command.is_appliance?
          session_options[:secure]    = true unless ENV["ALLOW_INSECURE_SESSION"]
          session_options[:httponly]  = true
          session_options[:same_site] = true
        end

        session_options
      end
    end
  end
end
