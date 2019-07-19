module Ansible
  class Runner
    class Credential
      attr_reader :auth, :base_dir

      def self.new(authentication_id, base_dir)
        auth_type = Authentication.find(authentication_id).type
        self == Ansible::Runner::Credential ? detect_credential_type(auth_type).new(authentication_id, base_dir) : super
      end

      def self.detect_credential_type(auth_type)
        subclasses.index_by(&:auth_type)[auth_type] || Ansible::Runner::GenericCredential
      end

      def initialize(authentication_id, base_dir)
        @auth     = Authentication.find(authentication_id)
        @base_dir = base_dir

        FileUtils.mkdir_p(env_dir)
      end

      def command_line
        {}
      end

      def env_vars
        {}
      end

      def extra_vars
        {}
      end

      def write_config_files
      end

      private

      def initialize_password_data
        File.exist?(password_file) ? YAML.load_file(password_file) : {}
      end

      def password_file
        File.join(env_dir, "passwords")
      end

      def ssh_key_file
        File.join(env_dir, "ssh_key")
      end

      def env_dir
        File.join(base_dir, "env")
      end
    end
  end
end

Dir.glob(File.join(File.dirname(__FILE__), "credential/*.rb")).each { |f| require_dependency f }
