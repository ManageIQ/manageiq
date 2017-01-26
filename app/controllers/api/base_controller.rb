module Api
  #
  # Initializing REST API environment, called once @ startup
  #
  Initializer.new.go

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
    include_concern 'ErrorHandler'
    include_concern 'Normalizer'
    include_concern 'Renderer'
    include_concern 'Results'
    include_concern 'Generic'
    include_concern 'Authentication'
    include CompressedIds
    include ActionController::HttpAuthentication::Basic::ControllerMethods
    extend ErrorHandler::ClassMethods

    before_action :require_api_user_or_token, :except => [:handle_options_request]
    before_action :set_gettext_locale
    before_action :set_access_control_headers
    before_action :parse_api_request, :log_api_request, :validate_api_request
    before_action :validate_api_action, :except => [:options]
    before_action :log_request_initiated, :only => [:handle_options_request]
    before_action :validate_response_format, :except => [:destroy]
    after_action :log_api_response

    respond_to :json
    rescue_from_api_errors

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
  end
end
