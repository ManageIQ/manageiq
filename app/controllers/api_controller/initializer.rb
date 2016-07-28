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
      def fetch_encrypted_attribute_names(klass)
        return [] unless klass.respond_to?(:encrypted_columns)
        encrypted_objects_checked[klass.name] ||= klass.encrypted_columns.each do |attr|
          Api.normalized_attributes[:encrypted][attr] = true
        end
      end

      def encrypted_objects_checked
        @encrypted_objects_checked ||= {}
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
        log_config
      end

      def log_config
        $api_log.info("")
        $api_log.info("Static Configuration")
        Api::Settings.base.each { |key, val| log_kv(key, val) }

        $api_log.info("")
        $api_log.info("Dynamic Configuration")
        Api.user_token_service.api_config.each { |key, val| log_kv(key, val) }
      end

      #
      # Let's create our attribute type hashes.
      # Accessed as normalized_attributes[<name>], much faster than array include?
      #
      def gen_attr_type_hash
        ATTR_TYPES.each { |type, attrs| attrs.each { |a| Api.normalized_attributes[type][a] = true } }
        gen_time_attr_type_hash
      end

      #
      # Let's dynamically get the :date and :datetime attributes from the Classes we care about.
      #
      def gen_time_attr_type_hash
        Api::Settings.collections.each do |_, cspec|
          next if cspec[:klass].blank?
          klass = cspec[:klass].constantize
          klass.columns_hash.collect  do |name, typeobj|
            Api.normalized_attributes[:time][name] = true if %w(date datetime).include?(typeobj.type.to_s)
          end
        end
      end
    end
  end
end
