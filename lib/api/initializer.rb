module Api
  class Initializer
    def go
      init_env
    end

    def log_kv(key, val)
      $api_log.info("  #{key.to_s.ljust([24, key.to_s.length].max, ' ')}: #{val}")
    end

    #
    # Initializing REST API environment, called once @ startup
    #
    def init_env
      $api_log.info("Initializing Environment for #{ApiConfig.base[:name]}")
      log_config
    end

    def log_config
      $api_log.info("")
      $api_log.info("Static Configuration")
      ApiConfig.base.each { |key, val| log_kv(key, val) }

      $api_log.info("")
      $api_log.info("Dynamic Configuration")
      Environment.user_token_service.api_config.each { |key, val| log_kv(key, val) }
    end
  end
end
