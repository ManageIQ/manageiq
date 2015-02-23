class ApiController
  module Initializer
    extend ActiveSupport::Concern

    included do
      @config = load_config
      init_env
      gen_attr_type_hash
    end

    module ClassMethods
      #
      # Load REST API Config, Versioning, Methods, Collections and Actions
      # from the api.tmpl.yml file.
      #
      # For API Versioning - no ident in the version definitions means that
      # version is not be advertised by the entrypoint.
      #
      # URLs without the v#.# versioning default to :version listed
      # in the :base section which must also exist in the :version
      # definition section.
      #
      def load_config
        @config = YAML.load_file(Rails.root.join("config/api.yml"))
      end

      def base_config
        @config[:base]
      end

      def version_config
        @config[:version]
      end

      def collection_config
        @config[:collections]
      end

      private

      def log_kv(key, val, pref = "")
        $api_log.info("#{pref}  #{key.to_s.ljust([24, key.to_s.length].max, ' ')}: #{val}")
      end

      #
      # Initializing REST API environment, called once @ startup
      #
      def init_env(cfg = VMDB::Config.new("vmdb"))
        mod  = base_config[:module]
        name = base_config[:name]

        $api_log.info("Initializing Environment for #{name}")

        $api_log.info("")
        $api_log.info("Static Configuration")
        base_config.each { |key, val| log_kv(key, val) }

        [:token_ttl, :authentication_timeout].each do |key|
          cfg.merge_from_template_if_missing([mod.to_sym] + [key])
        end

        [:level_api, :level_api_in_evm].each do |key|
          cfg.merge_from_template_if_missing([:log] + [key])
        end

        $api_log.info("")
        $api_log.info("Dynamic Configuration")
        api_config = cfg.config[mod.to_sym]
        api_config.each { |key, val| log_kv(key, val) }

        new_token_mgr(mod, name, api_config)
      end

      #
      # Let's create a new token manager for the API
      #
      def new_token_mgr(mod, name, api_config)
        token_ttl   = api_config[:token_ttl]

        options                          = {}
        options[:token_ttl]              = token_ttl.to_i_with_method if token_ttl

        $api_log.info("")
        $api_log.info("Creating new Token Manager for the #{name}")
        $api_log.info("   Token Manager  module: #{mod}")
        $api_log.info("   Token Manager options:")
        options.each { |key, val| log_kv(key, val, "    ") }
        $api_log.info("")

        TokenManager.new(mod, options)
      end

      #
      # Let's create our attribute type hashes.
      # Accessed as @attr_<type>[<name>], much faster than array include?
      #
      def gen_attr_type_hash
        @attr_time = {}
        @attr_url  = {}

        ATTR_TYPES[:time].each { |attr| @attr_time[attr] = true }
        ATTR_TYPES[:url].each  { |attr| @attr_url[attr]  = true }
        #
        # Let's dynamically get the :date and :datetime attributes from the Classes we care about.
        #
        collection_config.values.each do |cspec|
          unless cspec[:klass].blank?
            klass = cspec[:klass].constantize
            klass.columns_hash.collect  do |name, typeobj|
              @attr_time[name] = true if %w(date datetime).include?(typeobj.type.to_s)
            end
          end
        end
      end
    end
  end
end
