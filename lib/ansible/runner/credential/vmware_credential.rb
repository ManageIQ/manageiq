module Ansible
  class Runner
    class VmwareCredential < Credential
      def self.auth_type
        "ManageIQ::Providers::EmbeddedAnsible::AutomationManager::VmwareCredential"
      end

      # Modeled off of vmware injectors for awx:
      #
      #   https://github.com/ansible/awx/blob/1242ee2b/awx/main/models/credential/injectors.py#L63-L67
      #
      # NOTE:  The VMWARE_VALIDATE_CERTS is currently not supported.
      #
      def env_vars
        {
          "VMWARE_USER"     => auth.userid || "",
          "VMWARE_PASSWORD" => auth.password || "",
          "VMWARE_HOST"     => auth.host || ""
        }
      end
    end
  end
end
