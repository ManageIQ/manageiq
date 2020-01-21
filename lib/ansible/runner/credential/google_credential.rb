module Ansible
  class Runner
    class GoogleCredential < Credential
      def self.auth_type
        "ManageIQ::Providers::EmbeddedAnsible::AutomationManager::GoogleCredential"
      end

      # Modeled off of gce injectors for awx:
      #
      #   https://github.com/ansible/awx/blob/1242ee2b/awx/main/models/credential/injectors.py#L18-L42
      #
      def env_vars
        {
          "GCE_EMAIL"                 => auth.userid || "",
          "GCE_PROJECT"               => auth.project || "",
          "GCE_CREDENTIALS_FILE_PATH" => gce_credentials_file
        }
      end

      def write_config_files
        write_gce_credentials_file
      end

      private

      def write_gce_credentials_file
        json_data = {
          :type         => "service_account",
          :private_key  => auth.auth_key || "",
          :client_email => auth.userid || "",
          :project_id   => auth.project || ""
        }

        File.write(gce_credentials_file, json_data.to_json)
        File.chmod(0o0600, gce_credentials_file)
      end

      def gce_credentials_file
        File.join(base_dir, "gce_credentials")
      end
    end
  end
end
