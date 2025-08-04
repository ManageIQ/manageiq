module ManageIQ
  module Session
    module RackSessionDalliLogger
      def log_rack_session_access(*args, **_kwargs)
        request = args.first
        Rails.logger.debug("RackSessionDalliLogger##{caller_locations.first.label.ljust(14, ' ')} id: #{request.request_id} method: #{request.request_method} fullpath: #{request.fullpath}")
      end

      def find_session(...)
        log_rack_session_access(...)
        super
      end

      def write_session(...)
        log_rack_session_access(...)
        super
      end

      def delete_session(...)
        log_rack_session_access(...)
        super
      end
    end
  end
end

