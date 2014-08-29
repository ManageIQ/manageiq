module ApiHelper
  module ErrorHandler
    #
    # Class Methods
    #

    module ClassMethods
      def rescue_from_api_errors
        ApiController::ERROR_MAPPING.each do |error, type|
          rescue_from error do |e|
            api_exception_type(type, e)
          end
        end
      end
    end

    def api_exception_type(type, e)
      api_error(type, e.message, e, e.backtrace.join("\n"), Rack::Utils.status_code(type))
    end

    def api_error_type(type, message)
      api_error(type, message, self.class, "", Rack::Utils.status_code(type))
    end

    private

    def api_error(kind, message, e_obj, backtrace, status)
      err = {
        :kind    => kind,
        :message => message,
        :klass   => e_obj.name || e_obj.class.name
      }
      # We don't want to return the stack trace, but only log it in case of an internal error
      api_log_error("#{message}\n\n#{backtrace}") if kind == :internal_server_error && !backtrace.empty?

      if status == 405
        response.headers['Allow'] = klass.allowed_methods
      end
      render :json => {:error => err}, :status => status
    end
  end
end
