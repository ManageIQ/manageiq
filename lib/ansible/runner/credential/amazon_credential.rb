module Ansible
  class Runner
    class AmazonCredential < Credential
      def self.auth_type
        "ManageIQ::Providers::EmbeddedAnsible::AutomationManager::AmazonCredential"
      end

      # Modeled off of aws injectors for awx:
      #
      #   https://github.com/ansible/awx/blob/1242ee2b/awx/main/models/credential/injectors.py#L11-L15
      #
      def env_vars
        {
          "AWS_ACCESS_KEY_ID"     => auth.userid || "",
          "AWS_SECRET_ACCESS_KEY" => auth.password || "",
          "AWS_SECURITY_TOKEN"    => auth.auth_key
        }.delete_nils
      end
    end
  end
end
