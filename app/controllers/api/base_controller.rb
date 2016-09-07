module Api
  #
  # Initializing REST API environment, called once @ startup
  #
  Initializer.new.go

  class BaseController < ApplicationController
    skip_before_action :get_global_session_data
    skip_after_action :set_global_session_data

    def handle_options_request
      head(:ok)
    end

    before_action :set_access_control_headers
    def set_access_control_headers
      headers['Access-Control-Allow-Origin'] = '*'
      headers['Access-Control-Allow-Headers'] = 'origin, content-type, authorization, x-auth-token'
      headers['Access-Control-Allow-Methods'] = 'GET, POST, PUT, DELETE, PATCH, OPTIONS'
    end

    #
    # Support for REST API
    #
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

    #
    # Api Controller Hooks
    #
    extend ErrorHandler::ClassMethods
    respond_to :json
    rescue_from_api_errors
    prepend_before_action :require_api_user_or_token, :except => [:handle_options_request]

    TAG_NAMESPACE = "/managed"

    #
    # Attributes used for identification
    #
    ID_ATTRS = %w(href id)

    #
    # To skip CSRF token verification as API clients would
    # not have these. They would instead dealing with the /api/auth
    # mechanism.
    #
    if Vmdb::Application.config.action_controller.allow_forgery_protection
      skip_before_action :verify_authenticity_token,
                         :only => [:show, :update, :destroy, :handle_options_request, :options]
    end

    def collection_config
      @collection_config ||= CollectionConfig.new
    end

    before_action :parse_api_request, :log_api_request, :validate_api_request
    before_action :validate_api_action, :except => [:options]
    before_action :log_request_initiated, :only => [:handle_options_request]
    before_action :validate_response_format, :except => [:destroy]
    after_action :log_api_response

    private

    def validate_response_format
      accept = request.headers["Accept"]
      return if accept.blank? || accept.include?("json") || accept.include?("*/*")
      raise UnsupportedMediaTypeError, "Invalid Response Format #{accept} requested"
    end
  end
end
