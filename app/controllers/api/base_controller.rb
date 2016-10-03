module Api
  #
  # Initializing REST API environment, called once @ startup
  #
  Initializer.new.go

  class BaseController < ApplicationController
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
    extend ErrorHandler::ClassMethods

    #
    # To skip CSRF token verification as API clients would
    # not have these. They would instead dealing with the /api/auth
    # mechanism.
    #
    if Vmdb::Application.config.action_controller.allow_forgery_protection
      skip_before_action :verify_authenticity_token,
                         :only => [:show, :update, :destroy, :handle_options_request, :options]
    end
    skip_before_action :get_global_session_data
    skip_before_action :reset_toolbar
    skip_before_action :set_session_tenant
    skip_before_action :set_user_time_zone
    skip_before_action :allow_websocket
    skip_after_action :set_global_session_data
    before_action :set_access_control_headers
    prepend_before_action :require_api_user_or_token, :except => [:handle_options_request]
    before_action :parse_api_request, :log_api_request, :validate_api_request
    before_action :validate_api_action, :except => [:options]
    before_action :log_request_initiated, :only => [:handle_options_request]
    before_action :validate_response_format, :except => [:destroy]
    after_action :log_api_response

    respond_to :json
    rescue_from_api_errors

    private

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
