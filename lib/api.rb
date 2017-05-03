module Api
  ApiError = Class.new(StandardError)
  AuthenticationError = Class.new(ApiError)
  ForbiddenError = Class.new(ApiError)
  BadRequestError = Class.new(ApiError)
  NotFoundError = Class.new(ApiError)
  UnsupportedMediaTypeError = Class.new(ApiError)

  def self.encrypted_attribute?(attr)
    Environment.normalized_attributes[:encrypted].include?(attr.to_s) || attr.to_s.include?('password')
  end

  def self.time_attribute?(attr)
    Environment.normalized_attributes[:time].include?(attr.to_s)
  end

  def self.url_attribute?(attr)
    Environment.normalized_attributes[:url].include?(attr.to_s)
  end

  def self.resource_attribute?(attr)
    Environment.normalized_attributes[:resource].include?(attr.to_s)
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
