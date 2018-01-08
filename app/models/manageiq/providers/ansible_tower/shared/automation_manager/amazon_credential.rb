module ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::AmazonCredential
  COMMON_ATTRIBUTES = {
    :userid => {
      :label     => N_('Access Key'),
      :help_text => N_('AWS Access Key for this credential'),
      :required  => true
    },
    :password => {
      :type      => :password,
      :label     => N_('Secret Key'),
      :help_text => N_('AWS Secret Key for this credential'),
      :required  => true
    }
  }.freeze

  EXTRA_ATTRIBUTES = {
    :security_token => {
      :type       => :password,
      :label      => N_('STS Token'),
      :help_text  => N_('Security Token Service(STS) Token for this credential'),
      :max_length => 1024
    }
  }.freeze

  API_ATTRIBUTES = COMMON_ATTRIBUTES.merge(EXTRA_ATTRIBUTES).freeze

  API_OPTIONS = {
    :type       => 'cloud',
    :label      => N_('Amazon'),
    :attributes => API_ATTRIBUTES
  }.freeze
  TOWER_KIND = 'aws'.freeze
end
