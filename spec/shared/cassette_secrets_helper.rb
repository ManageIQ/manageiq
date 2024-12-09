module Spec
  module Shared
    module CassetteSecretsHelper
      DEFAULT_VCR_SECRETS_PATH = Pathname.new(Dir.pwd).join("config/secrets.defaults.yml")
      VCR_SECRETS_PATH         = Pathname.new(Dir.pwd).join("config/secrets.yml")

      def load_vcr_secrets(pathname)
        if pathname.exist?
          YAML.load_file(pathname)
        else
          {}
        end
      end

      def default_vcr_secrets
        @default_vcr_secrets ||= load_vcr_secrets(DEFAULT_VCR_SECRETS_PATH)
      end

      def vcr_secrets
        @vcr_secrets ||= load_vcr_secrets(VCR_SECRETS_PATH)
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
