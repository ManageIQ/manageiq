module ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::ScmCredential
  extend ActiveSupport::Concern

  COMMON_ATTRIBUTES = {
    :userid => {
      :label     => N_('Access Key'),
      :help_text => N_('AWS Access Key for this credential')
    },
    :password => {
      :type      => :password,
      :label     => N_('Secret Key'),
      :help_text => N_('AWS Secret Key for this credential')
    }
  }.freeze

  EXTRA_ATTRIBUTES = {
    :ssh_key_unlock => {
      :type       => :password,
      :label      => N_('Private key passphrase'),
      :help_text  => N_('Passphrase to unlock SSH private key if encrypted'),
      :max_length => 1024
    },
    :ssh_key_data => {
      :type       => :password,
      :label      => N_('Private key'),
      :help_text  => N_('RSA or DSA private key to be used instead of password')
    }
  }.freeze

  API_ATTRIBUTES = COMMON_ATTRIBUTES.merge(EXTRA_ATTRIBUTES).freeze
end
