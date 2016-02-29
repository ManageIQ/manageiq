class ApiController < ApplicationController
  skip_before_action :get_global_session_data
  skip_after_action :set_global_session_data

  class AuthenticationError < StandardError; end
  class Forbidden < StandardError; end
  class BadRequestError < StandardError; end
  class UnsupportedMediaTypeError < StandardError; end

  def handle_options_request
    head(:ok) if request.request_method == "OPTIONS"
  end

  before_action :set_access_control_headers
  def set_access_control_headers
    headers['Access-Control-Allow-Origin'] = '*'
    headers['Access-Control-Allow-Headers'] = 'origin, content-type, authorization, x-auth-token'
    headers['Access-Control-Allow-Methods'] = 'GET, POST, PUT, DELETE, PATCH'
  end

  # Order *Must* be from most generic to most specific
  ERROR_MAPPING = {
    StandardError                            => :internal_server_error,
    NoMethodError                            => :internal_server_error,
    ActiveRecord::RecordNotFound             => :not_found,
    ActiveRecord::StatementInvalid           => :bad_request,
    JSON::ParserError                        => :bad_request,
    MultiJson::LoadError                     => :bad_request,
    MiqException::MiqEVMLoginError           => :unauthorized,
    ApiController::AuthenticationError       => :unauthorized,
    ApiController::Forbidden                 => :forbidden,
    ApiController::BadRequestError           => :bad_request,
    ApiController::UnsupportedMediaTypeError => :unsupported_media_type
  }

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

  #
  # Support for API Collections
  #
  include_concern 'Entrypoint'
  include_concern 'Generic'

  include_concern 'Accounts'
  include_concern 'Authentication'
  include_concern 'AutomationRequests'
  include_concern 'Categories'
  include_concern 'CustomAttributes'
  include_concern 'Conditions'
  include_concern 'Groups'
  include_concern 'Policies'
  include_concern 'PolicyActions'
  include_concern 'Providers'
  include_concern 'Events'
  include_concern 'Features'
  include_concern 'Hosts'
  include_concern 'Instances'
  include_concern 'ProvisionRequests'
  include_concern "Rates"
  include_concern "Reports"
  include_concern 'RequestTasks'
  include_concern 'ResourceActions'
  include_concern 'Roles'
  include_concern 'Services'
  include_concern 'ServiceDialogs'
  include_concern 'ServiceRequests'
  include_concern 'ServiceTemplates'
  include_concern 'Software'
  include_concern 'Tags'
  include_concern 'Tenants'
  include_concern 'Users'
  include_concern 'Vms'

  #
  # Api Controller Hooks
  #
  extend ErrorHandler::ClassMethods
  respond_to :json
  rescue_from_api_errors
  before_action :require_api_user_or_token, :except => [:handle_options_request]

  TAG_NAMESPACE = "/managed"

  #
  # Custom normalization on these attribute types.
  # Converted to @attr_<type> hashes at init, much faster access.
  #
  ATTR_TYPES = {
    :time      => %w(expires_on),
    :url       => %w(href),
    :resource  => %w(image_href),
    :encrypted => %w(password) |
                  ::MiqRequestWorkflow.all_encrypted_options_fields.map(&:to_s) |
                  ::Vmdb::Settings::PASSWORD_FIELDS.map(&:to_s)
  }

  #
  # Attributes used for identification
  #
  ID_ATTRS = %w(href id)

  #
  # Requester type token ttl's for authentication
  #
  REQUESTER_TTL_CONFIG = {"ui" => :ui_token_ttl}

  #
  # To skip CSRF token verification as API clients would
  # not have these. They would instead dealing with the /api/auth
  # mechanism.
  #
  if Vmdb::Application.config.action_controller.allow_forgery_protection
    skip_before_action :verify_authenticity_token, :only => [:show, :update, :destroy, :handle_options_request]
  end

  delegate :base_config, :version_config, :collection_config, :to => self

  def initialize
    @config          = self.class.load_config
    @module          = base_config[:module]
    @name            = base_config[:name]
    @description     = base_config[:description]
    @version         = base_config[:version]
    @prefix          = "/#{@module}"
    @req             = {}      # To store API request details by parse_api_request
    @api_config      = VMDB::Config.new("vmdb").config[@module.to_sym] || {}
    @api_token_mgr   = TokenManager.new(@module)
  end

  #
  # Initializing REST API environment, called once @ startup
  #
  include_concern 'Initializer'

  def self.attr_type_hash(type)
    instance_variable_get("@attr_#{type}") || {}
  end

  def redirect_api_request(method)
    collection    = @req[:collection] || "entrypoint"
    target_method = "#{method}_#{collection}"
    if respond_to?(target_method)
      send(target_method)
      return true
    end
    target_method = "#{method}_generic"
    if respond_to?(target_method)
      send(target_method, collection.to_sym)
      return true
    end
    false
  end

  #
  # REST APIs Handler and API Entrypoints
  #
  def api_request_handler(expected_method)
    parse_api_request
    log_api_request
    validate_api_request
    api_error_type(:not_found, "Unknown resource specified") unless redirect_api_request(expected_method)
    log_api_response
  end

  def show    # GET
    api_request_handler(:show)
  end

  def update  # POST, PUT, PATCH
    api_request_handler(:update)
  end

  def destroy # DELETE
    api_request_handler(:destroy)
  end
end
