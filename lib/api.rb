module Api
  ApiError = Class.new(StandardError)
  AuthenticationError = Class.new(ApiError)
  ForbiddenError = Class.new(ApiError)
  BadRequestError = Class.new(ApiError)
  NotFoundError = Class.new(ApiError)
  UnsupportedMediaTypeError = Class.new(ApiError)

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

  def self.encrypted_attribute?(attr)
    Environment.encrypted_attributes.include?(attr.to_s) || attr.to_s.include?('password')
  end

  def self.time_attribute?(attr)
    Environment.time_attributes.include?(attr.to_s)
  end

  def self.url_attribute?(attr)
    Environment.url_attributes.include?(attr.to_s)
  end

  def self.resource_attribute?(attr)
    Environment.resource_attributes.include?(attr.to_s)
  end

  def self.init_env
    $api_log.info("Initializing Environment for #{ApiConfig.base[:name]}")
    $api_log.info("")
    $api_log.info("Static Configuration")
    ApiConfig.base.each { |key, val| log_kv(key, val) }

    $api_log.info("")
    $api_log.info("Dynamic Configuration")
    Environment.user_token_service.api_config.each { |key, val| log_kv(key, val) }
  end

  def self.log_kv(key, val)
    $api_log.info("  #{key.to_s.ljust([24, key.to_s.length].max, ' ')}: #{val}")
  end
end

Api.init_env
