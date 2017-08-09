module ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::NetworkCredential
  COMMON_ATTRIBUTES = {
    :userid => {
      :label     => N_('Username'),
      :help_text => N_('Username for this credential'),
      :required  => true
    },
    :password => {
      :type      => :password,
      :label     => N_('Password'),
      :help_text => N_('Password for this credential'),
      :required  => true
    }
  }.freeze

  EXTRA_ATTRIBUTES = {
    :authorize    => {
      :type       => :boolean,
      :label      => N_('Authorize'),
      :help_text  => N_('Whether to use the authorize mechanism')
    },
    :authorize_password => {
      :type       => :password,
      :label      => N_('Authorize password'),
      :help_text  => N_('Password used by the authorize mechanism')
    },
    :ssh_key_data => {
      :type       => :password,
      :multiline  => true,
      :label      => N_('SSH key'),
      :help_text  => N_('RSA or DSA private key to be used instead of password')
    },
    :ssh_key_unlock => {
      :type         => :password,
      :label        => N_('Private key passphrase'),
      :help_text    => N_('Passphrase to unlock SSH private key if encrypted'),
      :max_length   => 1024
    }
  }.freeze

  API_ATTRIBUTES = COMMON_ATTRIBUTES.merge(EXTRA_ATTRIBUTES).freeze

  API_OPTIONS = {
    :label      => N_('network'),
    :type       => 'network',
    :attributes => API_ATTRIBUTES
  }.freeze
  TOWER_KIND = 'net'.freeze
end
