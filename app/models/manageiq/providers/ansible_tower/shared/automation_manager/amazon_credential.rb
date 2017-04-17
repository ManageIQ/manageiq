module ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::AmazonCredential
  extend ActiveSupport::Concern

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
  LABEL = N_('Amazon')

  API_OPTIONS = {
    :type       => 'cloud',
    :label      => LABEL,
    :attributes => API_ATTRIBUTES
  }.freeze
  TOWER_KIND = 'aws'.freeze
end
