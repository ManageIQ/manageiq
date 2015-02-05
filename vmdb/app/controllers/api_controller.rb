class ApiController < ApplicationController
  class AuthenticationError       < StandardError; end
  class Forbidden                 < StandardError; end
  class BadRequestError           < StandardError; end
  class UnsupportedMediaTypeError < StandardError; end

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

  include ApiHelper

  #
  # Support for REST API
  #
  include_concern 'Parser'
  include_concern 'Manager'
  include_concern 'Action'

  #
  # Support for API Collections
  #
  include_concern 'Entrypoint'
  include_concern 'Generic'

  include_concern 'Accounts'
  include_concern 'Authentication'
  include_concern 'AutomationRequests'
  include_concern 'CustomAttributes'
  include_concern 'Conditions'
  include_concern 'Policies'
  include_concern 'PolicyActions'
  include_concern 'ProvisionRequests'
  include_concern 'RequestTasks'
  include_concern 'ServiceRequests'
  include_concern 'Software'
  include_concern 'ServiceTemplates'
  include_concern 'Tags'
  include_concern 'Vms'

  #
  # Api Controller Hooks
  #
  extend ApiHelper::ErrorHandler::ClassMethods
  respond_to :json
  rescue_from_api_errors
  before_filter :require_api_user_or_token

  TAG_NAMESPACE = "/managed"

  #
  # Custom normalization on these attribute types.
  # Converted to @attr_<type> hashes at init, much faster access.
  #
  ATTR_TYPES = {
    :time => %w(expires_on),
    :url  => %w(href)
  }

  #
  # Attributes used for identification
  #
  ID_ATTRS = %w(id href)

  #
  # To skip CSRF token verification as API clients would
  # not have these. They would instead dealing with the /api/auth
  # mechanism.
  #
  skip_before_filter :verify_authenticity_token, :only => [:show, :update, :destroy]

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
    validate_api_request
    api_error_type(:not_found, "Unknown resource specified") unless redirect_api_request(expected_method)
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
