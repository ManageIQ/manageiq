module ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::VmwareCredential
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
    :host => {
      :type       => :string,
      :label      => N_('vCenter Host'),
      :help_text  => N_('The hostname or IP address of the vCenter Host'),
      :max_length => 1024,
      :required   => true
    }
  }.freeze

  API_ATTRIBUTES = COMMON_ATTRIBUTES.merge(EXTRA_ATTRIBUTES).freeze

  API_OPTIONS = {
    :label      => N_('VMware'),
    :type       => 'cloud',
    :attributes => API_ATTRIBUTES
  }.freeze
  TOWER_KIND = 'vmware'.freeze
end
