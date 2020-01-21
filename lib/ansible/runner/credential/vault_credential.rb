module Ansible
  class Runner
    class VaultCredential < Credential
      def self.auth_type
        "ManageIQ::Providers::EmbeddedAnsible::AutomationManager::VaultCredential"
      end

      def env_vars
        if auth.vault_password.present?
          { "ANSIBLE_VAULT_PASSWORD_FILE" => vault_password_file }
        else
          {}
        end
      end

      def write_config_files
        write_vault_password_file if auth.vault_password.present?
      end

      private

      def write_vault_password_file
        File.write(vault_password_file, auth.vault_password)
        File.chmod(0o0400, vault_password_file)
      end

      def vault_password_file
        File.join(base_dir, "vault_password")
      end
    end
  end
end
