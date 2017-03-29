module Api
  class BaseController
    module ErrorHandler
      private

      def api_error(type, error)
        api_log_error("#{error.class.name}: #{error.message}")
        # We don't want to return the stack trace, but only log it in case of an internal error
        api_log_error("\n\n#{error.backtrace.join("\n")}") if type == :internal_server_error && !error.backtrace.empty?

        render :json => ErrorSerializer.new(type, error).serialize, :status => Rack::Utils.status_code(type)
        log_api_response
      end
    end
  end
end
