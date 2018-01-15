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

    def settings
      id       = @req.collection_id
      type     = @req.collection
      klass    = collection_class(@req.collection)
      resource = resource_search(id, type, klass)

      case @req.method
      when :patch
        raise ForbiddenError, "You are not authorized to edit settings." unless super_admin?
        resource.add_settings_for_resource(@req.json_body)
      when :delete
        raise ForbiddenError, "You are not authorized to remove settings." unless super_admin?
        resource.remove_settings_path_for_resource(*@req.json_body)
        head :no_content
        return
      end

      if super_admin? || current_user.role_allows?(:identifier => 'ops_settings')
        render :json => whitelist_settings(resource.settings_for_resource.to_hash)
      else
        raise ForbiddenError, "You are not authorized to view settings."
      end
    end

    private

    def current_user
      User.current_user
    end

    def super_admin?
      current_user.super_admin_user?
    end

    def whitelist_settings(settings)
      return settings if super_admin?

      whitelisted_categories = ApiConfig.collections[:settings][:categories]
      settings.with_indifferent_access.slice(*whitelisted_categories)
    end

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
