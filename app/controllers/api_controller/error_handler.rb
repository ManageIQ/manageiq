class ApiController
  module ErrorHandler
    #
    # Class Methods
    #

    module ClassMethods
      def rescue_from_api_errors
        ERROR_MAPPING.each do |error, type|
          rescue_from error do |e|
            api_exception_type(type, e)
          end
        end
      end
    end

    def api_exception_type(type, e)
      api_error(type, e.message, e.class.name, e.backtrace.join("\n"), Rack::Utils.status_code(type))
    end

    def api_error_type(type, message)
      api_error(type, message, self.class.name, "", Rack::Utils.status_code(type))
    end

    private

    def api_error(kind, message, klass, backtrace, status)
      err = {
        :kind    => kind,
        :message => message,
        :klass   => klass
      }
      api_log_error("#{klass}: #{message}")
      # We don't want to return the stack trace, but only log it in case of an internal error
      api_log_error("\n\n#{backtrace}") if kind == :internal_server_error && !backtrace.empty?

      render :json => {:error => err}, :status => status
    end
  end
end
