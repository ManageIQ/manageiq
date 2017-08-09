module ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::AzureCredential
  COMMON_ATTRIBUTES = {
    :userid => {
      :label      => N_('Username'),
      :help_text  => N_('The username to use to connect to the Microsoft Azure account')
    },
    :password => {
      :type       => :password,
      :label      => N_('Password'),
      :help_text  => N_('The password to use to connect to the Microsoft Azure account')
    }
  }.freeze

  EXTRA_ATTRIBUTES = {
    :subscription => {
      :type       => :string,
      :label      => N_('Subscription ID'),
      :help_text  => N_('The Subscription UUID for the Microsoft Azure account'),
      :max_length => 1024,
      :required   => true
    },
    :tenant => {
      :type       => :string,
      :label      => N_('Tenant ID'),
      :help_text  => N_('The Tenant ID for the Microsoft Azure account'),
      :max_length => 1024
    },
    :secret => {
      :type       => :password,
      :label      => N_('Client Secret'),
      :help_text  => N_('The Client Secret for the Microsoft Azure account'),
      :max_length => 1024,
    },
    :client => {
      :type       => :string,
      :label      => N_('Client ID'),
      :help_text  => N_('The Client ID for the Microsoft Azure account'),
      :max_length => 128
    },
  }.freeze

  API_ATTRIBUTES = COMMON_ATTRIBUTES.merge(EXTRA_ATTRIBUTES).freeze

  API_OPTIONS = {
    :type       => 'cloud',
    :label      => N_('Azure'),
    :attributes => API_ATTRIBUTES
  }.freeze
  TOWER_KIND = 'azure_rm'.freeze
end
