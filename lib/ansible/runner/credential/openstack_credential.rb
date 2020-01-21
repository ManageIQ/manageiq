module Ansible
  class Runner
    class OpenstackCredential < Credential
      def self.auth_type
        "ManageIQ::Providers::EmbeddedAnsible::AutomationManager::OpenstackCredential"
      end

      # Modeled off of openstack injectors for awx:
      #
      #   https://github.com/ansible/awx/blob/1242ee2b/awx/main/models/credential/injectors.py#L70-L96
      #
      def env_vars
        { "OS_CLIENT_CONFIG_FILE" => os_credentials_file }
      end

      def write_config_files
        write_os_credentials_file
      end

      private

      def write_os_credentials_file
        openstack_data = {
          "clouds" => {
            "devstack" => {
              "verify" => false, # NOTE:  We don't have a way of configuring this currently
              "auth"   => {
                "auth_url"     => auth.host || "",
                "username"     => auth.userid || "",
                "password"     => auth.password || "",
                "project_name" => auth.project || "",
                "domain_name"  => auth.domain
              }.delete_nils
            }
          }
        }

        File.write(os_credentials_file, openstack_data.to_yaml)
        File.chmod(0o0600, os_credentials_file)
      end

      def os_credentials_file
        File.join(base_dir, "os_credentials")
      end
    end
  end
end
