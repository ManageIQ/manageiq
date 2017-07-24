module Api
  class BaseController < ActionController::API
    TAG_NAMESPACE = "/managed".freeze

    #
    # Attributes used for identification
    #
    ID_ATTRS = %w(href id).freeze

    include_concern 'Parameters'
    include_concern 'Parser'
    include_concern 'Manager'
    include_concern 'Action'
    include_concern 'Logger'
    include_concern 'Normalizer'
    include_concern 'Renderer'
    include_concern 'Results'
    include_concern 'Generic'
    include_concern 'Authentication'
    include ActionController::HttpAuthentication::Basic::ControllerMethods

    before_action :require_api_user_or_token, :except => [:handle_options_request]
    before_action :set_gettext_locale
    before_action :set_access_control_headers
    before_action :parse_api_request, :log_api_request, :validate_api_request
    before_action :validate_api_action, :except => [:options]
    before_action :log_request_initiated, :only => [:handle_options_request]
    before_action :validate_response_format, :except => [:destroy]
    after_action :log_api_response

    respond_to :json

    # Order *Must* be from most generic to most specific
    rescue_from(StandardError)                  { |e| api_error(:internal_server_error, e) }
    rescue_from(NoMethodError)                  { |e| api_error(:internal_server_error, e) }
    rescue_from(ActiveRecord::RecordNotFound)   { |e| api_error(:not_found, e) }
    rescue_from(ActiveRecord::StatementInvalid) { |e| api_error(:bad_request, e) }
    rescue_from(JSON::ParserError)              { |e| api_error(:bad_request, e) }
    rescue_from(MultiJson::LoadError)           { |e| api_error(:bad_request, e) }
    rescue_from(MiqException::MiqEVMLoginError) { |e| api_error(:unauthorized, e) }
    rescue_from(AuthenticationError)            { |e| api_error(:unauthorized, e) }
    rescue_from(ForbiddenError)                 { |e| api_error(:forbidden, e) }
    rescue_from(BadRequestError)                { |e| api_error(:bad_request, e) }
    rescue_from(NotFoundError)                  { |e| api_error(:not_found, e) }
    rescue_from(UnsupportedMediaTypeError)      { |e| api_error(:unsupported_media_type, e) }

    private

    def set_gettext_locale
      FastGettext.set_locale(LocaleResolver.resolve(User.current_user, headers))
    end

    def validate_response_format
      accept = request.headers["Accept"]
      return if accept.blank? || accept.include?("json") || accept.include?("*/*")
      raise UnsupportedMediaTypeError, "Invalid Response Format #{accept} requested"
    end

    def set_access_control_headers
      headers['Access-Control-Allow-Origin'] = '*'
      headers['Access-Control-Allow-Headers'] = 'origin, content-type, authorization, x-auth-token'
      headers['Access-Control-Allow-Methods'] = 'GET, POST, PUT, DELETE, PATCH, OPTIONS'
    end

    def collection_config
      @collection_config ||= CollectionConfig.new
    end

    def api_error(type, error)
      api_log_error("#{error.class.name}: #{error.message}")
      # We don't want to return the stack trace, but only log it in case of an internal error
      api_log_error("\n\n#{error.backtrace.join("\n")}") if type == :internal_server_error && !error.backtrace.empty?

      render :json => ErrorSerializer.new(type, error).serialize, :status => Rack::Utils.status_code(type)
      log_api_response
    end
  end
end
