module Ansible
  class Runner
    class MachineCredential < Credential
      def self.auth_type
        "ManageIQ::Providers::EmbeddedAnsible::AutomationManager::MachineCredential"
      end

      def command_line
        {:user => auth.userid}.delete_blanks.merge(become_args).tap do |args|
          # Add `--ask-pass` flag to ansible_playbook if we have a password to provide
          args[:ask_pass] = nil if auth.password.present?
        end
      end

      def write_config_files
        write_password_file
        write_ssh_key_file
      end

      private

      def become_args
        return {} if auth.become_username.blank?

        {
          :become        => nil,
          :become_user   => auth.become_username,
          :become_method => auth.options.try(:[], :become_method) || "sudo"
        }
      end

      def write_password_file
        password_hash = {
          "^SSH [pP]assword:"                                     => auth.password,
          "^BECOME [pP]assword:"                                  => auth.become_password,
          "^Enter passphrase for [a-zA-Z0-9\-\/]+\/ssh_key_data:" => auth.ssh_key_unlock
        }.delete_blanks

        File.write(password_file, password_hash.to_yaml) if password_hash.present?
      end

      def write_ssh_key_file
        File.write(ssh_key_file, auth.auth_key) if auth.auth_key.present?
      end
    end
  end
end
