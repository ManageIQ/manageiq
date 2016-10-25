module Api
  class Initializer
    def go
      init_env
      gen_attr_type_hash
    end

    def log_kv(key, val, pref = "")
      $api_log.info("#{pref}  #{key.to_s.ljust([24, key.to_s.length].max, ' ')}: #{val}")
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

    #
    # Let's create our attribute type hashes.
    # Accessed as normalized_attributes[<name>], much faster than array include?
    #
    def gen_attr_type_hash
      attr_types.each { |type, attrs| attrs.each { |a| Environment.normalized_attributes[type][a] = true } }
      gen_time_attr_type_hash
    end

    #
    # Let's dynamically get the :date and :datetime attributes from the Classes we care about.
    #
    def gen_time_attr_type_hash
      ApiConfig.collections.each do |_, cspec|
        next if cspec[:klass].blank?
        klass = cspec[:klass].constantize
        klass.columns_hash.collect do |name, typeobj|
          Environment.normalized_attributes[:time][name] = true if %w(date datetime).include?(typeobj.type.to_s)
        end
      end
    end

    private

    #
    # Custom normalization on these attribute types.
    # Converted to normalized_attributes hash at init, much faster access.
    #
    def attr_types
      @attr_types ||= {
        :time      => %w(expires_on),
        :url       => %w(href),
        :resource  => %w(image_href),
        :encrypted => %w(password) |
                      ::MiqRequestWorkflow.all_encrypted_options_fields.map(&:to_s) |
                      ::Vmdb::Settings::PASSWORD_FIELDS.map(&:to_s)
      }
    end
  end
end
