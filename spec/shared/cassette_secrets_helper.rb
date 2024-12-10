module Spec
  module Shared
    module CassetteSecretsHelper
      def default_vcr_secrets_path
        Pathname.new(Dir.pwd).join("config/secrets.defaults.yml").tap do |path|
          raise "Default vcr cassette secrets not found: #{path}! Create this file with placeholder secrets to be used in cassettes to avoid leaking actual secrets." unless path.exist?
        end
      end

      def vcr_secrets_path
        Pathname.new(Dir.pwd).join("config/secrets.yml")
      end

      def load_vcr_secrets(pathname)
        if pathname.exist?
          YAML.load_file(pathname)
        else
          {}
        end
      end

      def default_vcr_secrets
        @@default_vcr_secrets ||= load_vcr_secrets(default_vcr_secrets_path)
      end

      def vcr_secrets
        @@vcr_secrets ||= load_vcr_secrets(vcr_secrets_path)
      end

      def default_vcr_secret_by_key_path(*args)
        default_vcr_secrets.dig(*args)
      end

      def vcr_secret_by_key_path(*args)
        vcr_secrets.dig(*args) || default_vcr_secret_by_key_path(*args)
      end
    end
  end
end
