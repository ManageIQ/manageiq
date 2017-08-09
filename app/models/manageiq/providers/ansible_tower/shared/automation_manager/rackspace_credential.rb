module ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::RackspaceCredential
  COMMON_ATTRIBUTES = {
    :userid => {
      :label     => N_('Username'),
      :help_text => N_('Username for this credential'),
      :required  => true
    },
    :password => {
      :type      => :password,
      :label     => N_('API Key'),
      :help_text => N_('API Key for this credential'),
      :required  => true
    }
  }.freeze

  API_ATTRIBUTES = COMMON_ATTRIBUTES

  API_OPTIONS = {
    :type       => 'cloud',
    :label      => N_('Rackspace'),
    :attributes => API_ATTRIBUTES
  }.freeze
  TOWER_KIND = 'rax'.freeze
end
