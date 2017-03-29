module Api
  class BaseController
    module ErrorHandler
      # Order *Must* be from most generic to most specific
      ERROR_MAPPING = {
        StandardError                  => :internal_server_error,
        NoMethodError                  => :internal_server_error,
        ActiveRecord::RecordNotFound   => :not_found,
        ActiveRecord::StatementInvalid => :bad_request,
        JSON::ParserError              => :bad_request,
        MultiJson::LoadError           => :bad_request,
        MiqException::MiqEVMLoginError => :unauthorized,
        AuthenticationError            => :unauthorized,
        ForbiddenError                 => :forbidden,
        BadRequestError                => :bad_request,
        NotFoundError                  => :not_found,
        UnsupportedMediaTypeError      => :unsupported_media_type
      }.freeze

      #
      # Class Methods
      #

      module ClassMethods
        def rescue_from_api_errors
          ERROR_MAPPING.each { |error, type| rescue_from(error) { |e| api_error(type, e) } }
        end
      end

      private

      def api_error(type, error)
        message = error.message
        klass = error.class.name
        backtrace = error.backtrace.join("\n")
        status = Rack::Utils.status_code(type)

        api_log_error("#{klass}: #{message}")
        # We don't want to return the stack trace, but only log it in case of an internal error
        api_log_error("\n\n#{backtrace}") if type == :internal_server_error && !backtrace.empty?

        render :json => ErrorSerializer.new(type, error).serialize, :status => status
        log_api_response
      end
    end
  end
end
