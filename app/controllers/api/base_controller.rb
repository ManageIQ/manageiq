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

    def log_request_initiated
      @requested_at = Time.now.utc
      api_log_info { " " }
      api_log_info do
        format_data_for_logging("API Request",
                                :requested_at => @requested_at.to_s,
                                :method       => request.request_method,
                                :url          => request.original_url)
      end
    end

    def log_api_request
      @parameter_filter ||= ActionDispatch::Http::ParameterFilter.new(Rails.application.config.filter_parameters)
      api_log_info { format_data_for_logging("Request", @req.to_hash) }

      api_log_info do
        unfiltered_params = request.query_parameters
                                   .merge(params.permit(:action, :controller, :format).to_h)
                                   .merge("body" => @req.json_body)
        format_data_for_logging("Parameters", @parameter_filter.filter(unfiltered_params))
      end
      log_request_body
    end

    def log_request_body
      if @req.json_body.present?
        api_log_debug { format_data_for_logging("Body", JSON.pretty_generate(@req.json_body)) }
      end
    end

    def log_api_response
      @completed_at = Time.now.utc
      api_log_info do
        format_data_for_logging("Response",
                                :completed_at => @completed_at.to_s,
                                :size         => '%.3f KBytes' % (response.body.size / 1000.0),
                                :time_taken   => '%.3f Seconds' % (@completed_at - @requested_at),
                                :status       => response.status)
      end
    end

    def format_data_for_logging(header, data)
      "#{('%s:' % header).ljust(15)} #{data}"
    end
  end
end
