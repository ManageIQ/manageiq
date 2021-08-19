module Ansible
  class Runner
    class IbmCloudCredential < Credential
      def self.auth_type
        "ManageIQ::Providers::IbmCloud::IbmCloudCredential"
      end

      def env_vars
        {
          :creds_aes_key => auth.auth_key,
          :creds_aes_iv  => auth.auth_key_password
        }
      end
    end
  end
end
