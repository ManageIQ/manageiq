class ApiController
  module Initializer
    extend ActiveSupport::Concern

    included do
      init_env
      gen_attr_type_hash
    end

    module ClassMethods
      #
      # Let's fetch encrypted attribute names of objects being rendered if not already done
      #
      def fetch_encrypted_attribute_names(obj)
        @encrypted_objects_checked ||= {}
        klass = obj.class.name
        return unless @encrypted_objects_checked[klass].nil?
        @encrypted_objects_checked[klass] = object_encrypted_attributes(obj)
        @encrypted_objects_checked[klass].each { |attr| @attr_encrypted[attr] = true }
      end

      def user_token_service
        @api_user_token_service
      end

      private

      def log_kv(key, val, pref = "")
        $api_log.info("#{pref}  #{key.to_s.ljust([24, key.to_s.length].max, ' ')}: #{val}")
      end

      #
      # Initializing REST API environment, called once @ startup
      #
      def init_env
        $api_log.info("Initializing Environment for #{Api::Settings.base[:name]}")
        @api_user_token_service ||= ApiUserTokenService.new(Api::Settings.data, :log_init => true)
        log_config
      end

      def log_config
        $api_log.info("")
        $api_log.info("Static Configuration")
        Api::Settings.base.each { |key, val| log_kv(key, val) }

        $api_log.info("")
        $api_log.info("Dynamic Configuration")
        user_token_service.api_config.each { |key, val| log_kv(key, val) }
      end

      #
      # Let's create our attribute type hashes.
      # Accessed as @attr_<type>[<name>], much faster than array include?
      #
      def gen_attr_type_hash
        @attr_time = {}
        @attr_url  = {}
        @attr_resource  = {}
        @attr_encrypted = {}

        ATTR_TYPES[:time].each { |attr| @attr_time[attr] = true }
        ATTR_TYPES[:url].each  { |attr| @attr_url[attr]  = true }
        ATTR_TYPES[:resource].each  { |attr| @attr_resource[attr]  = true }
        ATTR_TYPES[:encrypted].each { |attr| @attr_encrypted[attr] = true }

        gen_time_attr_type_hash
      end

      #
      # Let's dynamically get the :date and :datetime attributes from the Classes we care about.
      #
      def gen_time_attr_type_hash
        Api::Settings.collections.each_value do |cspec|
          next if cspec[:klass].blank?
          klass = cspec[:klass].constantize
          klass.columns_hash.collect  do |name, typeobj|
            @attr_time[name] = true if %w(date datetime).include?(typeobj.type.to_s)
          end
        end
      end

      def object_encrypted_attributes(obj)
        obj.class.respond_to?(:encrypted_columns) ? obj.class.encrypted_columns : []
      end
    end
  end
end
