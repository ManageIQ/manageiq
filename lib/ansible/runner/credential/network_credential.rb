module Ansible
  class Runner
    class NetworkCredential < Credential
      def self.auth_type
        "ManageIQ::Providers::EmbeddedAnsible::AutomationManager::NetworkCredential"
      end

      # Modeled off of awx codebase:
      #
      #   https://github.com/ansible/awx/blob/1242ee2b/awx/main/tasks.py#L1432-L1443
      #
      def env_vars
        env = {
          "ANSIBLE_NET_USERNAME"  => auth.userid || "",
          "ANSIBLE_NET_PASSWORD"  => auth.password || "",
          "ANSIBLE_NET_AUTHORIZE" => auth.authorize ? "1" : "0"
        }

        env["ANSIBLE_NET_AUTH_PASS"]   = auth.become_password || "" if auth.authorize
        env["ANSIBLE_NET_SSH_KEYFILE"] = network_ssh_key_file       if auth.auth_key
        env
      end

      def write_config_files
        write_password_file
        write_network_ssh_key_file if auth.auth_key
      end

      private

      SSH_UNLOCK_KEY = "^Enter passphrase for [a-zA-Z0-9\-\/]+\/ssh_key_data:".freeze
      def write_password_file
        password_data = initialize_password_data
        password_data[SSH_UNLOCK_KEY] ||= auth.ssh_key_unlock || ""
        File.write(password_file, password_data.to_yaml)
      end

      def write_network_ssh_key_file
        File.write(network_ssh_key_file, auth.auth_key)
        File.chmod(0o0400, network_ssh_key_file)
      end

      def network_ssh_key_file
        File.join(env_dir, "network_ssh_key")
      end
    end
  end
end
