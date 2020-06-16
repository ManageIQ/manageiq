module Ansible
  class Runner
    class MachineCredential < Credential
      def self.auth_type
        "ManageIQ::Providers::EmbeddedAnsible::AutomationManager::MachineCredential"
      end

      def command_line
        {:user => auth.userid}.delete_blanks.merge(become_args).tap do |args|
          # Add `--ask-pass` or `--ask-become-pass` flags to ansible_playbook
          # if we have a password to provide
          args[:ask_pass] = nil if auth.password.present?
          args[:ask_become_pass] = nil if auth.become_password.present?
        end
      end

      def write_config_files
        write_password_file
        write_ssh_key_file
      end

      private

      def become_args
        {
          :become_user   => auth.become_username,
          :become_method => auth.options.try(:[], :become_method) || "sudo"
        }.delete_blanks
      end

      SSH_KEY        = "^SSH [pP]assword".freeze
      BECOME_KEY     = "^BECOME [pP]assword".freeze
      SSH_UNLOCK_KEY = "^Enter passphrase for [a-zA-Z0-9\-\/]+\/ssh_key_data:".freeze
      def write_password_file
        password_hash                 = initialize_password_data
        password_hash[SSH_KEY]        = auth.password        if auth.password
        password_hash[BECOME_KEY]     = auth.become_password if auth.become_password
        password_hash[SSH_UNLOCK_KEY] = auth.ssh_key_unlock  if auth.ssh_key_unlock

        File.write(password_file, password_hash.to_yaml) if password_hash.present?
      end

      def write_ssh_key_file
        File.write(ssh_key_file, auth.auth_key) if auth.auth_key.present?
      end
    end
  end
end
