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

      # Enables debug logging for Rack session operations.
      #
      # This method should be overridden by subclasses to implement session debugging.
      # When implemented, it should add logging capabilities to the Rack session class
      # used by the specific adapter.
      #
      # ## Implementation Guidelines
      #
      # 1. Create a module that adds logging to the Rack session methods:
      #    - `find_session`
      #    - `write_session`
      #    - `delete_session`
      #
      # 2. In your subclass implementation:
      #    - Skip logging in production environments
      #    - Require and specify the appropriate Rack session class for your adapter
      #    - Prepend your logging module to the Rack session class
      #
      # @example Implementation in a subclass
      #   def enable_rack_session_debug_logger
      #     return if Rails.env.production?
      #
      #     puts "** Enabling rack session debug logger"
      #     rack_session_class_to_prepend.prepend(MyLoggingModule)
      #   end
      #
      # @see ManageIQ::Session::RackSessionDalliLogger For a reference logging module
      # @see ManageIQ::Session::MemCacheStoreAdapter#enable_rack_session_debug_logger For a concrete implementation
      def enable_rack_session_debug_logger
        return if Rails.env.production?
      end
    end
  end
end
