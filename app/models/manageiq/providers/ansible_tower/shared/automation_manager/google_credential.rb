module ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::GoogleCredential
  COMMON_ATTRIBUTES = {
    :userid => {
      :type      => :email,
      :label     => N_('Service Account Email Address'),
      :help_text => N_('The email address assigned to the Google Compute Engine service account'),
      :required  => true
    }
  }.freeze

  EXTRA_ATTRIBUTES = {
    :ssh_key_data => {
      :type       => :password,
      :multiline  => true,
      :label      => N_('RSA Private Key'),
      :help_text  => N_('Contents of the PEM file associated with the service account email'),
      :required  => true
    },
    :project => {
      :type       => :string,
      :label      => N_('Project'),
      :help_text  => N_('The GCE assigned identification. It is constructed as two words followed by a three digit number, such as: squeamish-ossifrage-123'),
      :max_length => 100,
    }
  }.freeze

  API_ATTRIBUTES = COMMON_ATTRIBUTES.merge(EXTRA_ATTRIBUTES).freeze

  API_OPTIONS = {
    :type       => 'cloud',
    :label      => N_('Google Compute Engine'),
    :attributes => API_ATTRIBUTES
  }.freeze
  TOWER_KIND = 'gce'.freeze
end
