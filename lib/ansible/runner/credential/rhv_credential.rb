module Ansible
  class Runner
    class RhvCredential < Credential
      def self.auth_type
        "ManageIQ::Providers::EmbeddedAnsible::AutomationManager::RhvCredential"
      end

      # Modeled off of rhv injectors for awx:
      #
      #   https://github.com/ansible/awx/blob/1242ee2b/awx/main/models/credential/__init__.py#L1035-L1054
      #
      def env_vars
        {
          "OVIRT_INI_PATH" => ovirt_ini_file,
          "OVIRT_URL"      => auth.host || "",
          "OVIRT_USERNAME" => auth.userid || "",
          "OVIRT_PASSWORD" => auth.password || "",
        }
      end

      def write_config_files
        write_ovirt_ini_file
      end

      private

      def write_ovirt_ini_file
        ovirt_data = %W[
          [ovirt]
          ovirt_url=#{auth.host}
          ovirt_username=#{auth.userid}
          ovirt_password=#{auth.password}
        ]

        # NOTE:  We currently DO NOT support ca_file support as is in `awx`.
        #
        # ansible/awx ref:
        #
        #   https://github.com/ansible/awx/blob/1242ee2b/awx/main/models/credential/__init__.py#L1046
        #
        # To add, we need to update the GoogleCredential::API_OPTIONS in
        # app/models and add the following line here:
        #
        # ovirt_data << "ovirt_ca_file=#{auth.auth_key}" if auth.auth_key

        File.write(ovirt_ini_file, ovirt_data.join("\n"))
        File.chmod(0o0600, ovirt_ini_file)
      end

      def ovirt_ini_file
        File.join(base_dir, "ovirt.ini")
      end
    end
  end
end
