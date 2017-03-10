module ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::MachineCredential
  extend ActiveSupport::Concern

  COMMON_ATTRIBUTES = {
    :userid => {
      :label     => N_('Username'),
      :help_text => N_('Username for this credential')
    },
    :password => {
      :type      => :password,
      :label     => N_('Password'),
      :help_text => N_('Password for this credential')
    }
  }.freeze

  EXTRA_ATTRIBUTES = {
    :ssh_key_data => {
      :type       => :password,
      :label      => N_('Private key'),
      :help_text  => N_('RSA or DSA private key to be used instead of password')
    },
    :ssh_key_unlock => {
      :type       => :password,
      :label      => N_('Private key passphrase'),
      :help_text  => N_('Passphrase to unlock SSH private key if encrypted'),
      :max_length => 1024
    },
    :become_method => {
      :type       => :choice,
      :label      => N_('Privilege Escalation'),
      :help_text  => N_('Privilege escalation method'),
      :choices    => ['', 'sudo', 'su', 'pbrun', 'pfexec']
    },
    :become_username => {
      :type       => :string,
      :label      => N_('Privilege Escalation Username'),
      :help_text  => N_('Privilege escalation username'),
      :max_length => 1024
    },
    :become_password => {
      :type       => :password,
      :label      => N_('Privilege Escalation Password'),
      :help_text  => N_('Password for privilege escalation method'),
      :max_length => 1024
    },
    :vault_password => {
      :type       => :password,
      :label      => N_('Vault password'),
      :help_text  => N_('Vault password'),
      :max_length => 1024
    }
  }.freeze

  API_ATTRIBUTES = COMMON_ATTRIBUTES.merge(EXTRA_ATTRIBUTES).freeze
end
