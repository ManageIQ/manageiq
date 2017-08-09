module ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::Satellite6Credential
  COMMON_ATTRIBUTES = {
    :userid => {
      :label      => N_('Username'),
      :help_text  => N_('The username to use to connect to Satellite 6'),
      :required   => true
    },
    :password => {
      :type       => :password,
      :label      => N_('Password'),
      :help_text  => N_('The password to use to connect to Satellite 6'),
      :required   => true
    }
  }.freeze

  EXTRA_ATTRIBUTES = {
    :host => {
      :type       => :string,
      :label      => N_('Satellite 6 Host'),
      :help_text  => N_('Hostname or IP address which corresponds to your Red Hat Satellite 6 server'),
      :max_length => 1024,
      :required   => true
    }
  }.freeze

  API_ATTRIBUTES = COMMON_ATTRIBUTES.merge(EXTRA_ATTRIBUTES).freeze

  API_OPTIONS = {
    :type       => 'cloud',
    :label      => N_('Satellite6'),
    :attributes => API_ATTRIBUTES
  }.freeze
  TOWER_KIND = 'satellite6'.freeze
end
