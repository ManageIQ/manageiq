module ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::VmwareCredential
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
    :host => {
      :type       => :string,
      :label      => N_('vCenter Host'),
      :help_text  => N_('The hostname or IP address of the vCenter Host'),
      :max_length => 1024
    }
  }.freeze

  API_ATTRIBUTES = COMMON_ATTRIBUTES.merge(EXTRA_ATTRIBUTES).freeze
end
