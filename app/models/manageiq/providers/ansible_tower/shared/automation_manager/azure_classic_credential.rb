module ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::AzureClassicCredential
  COMMON_ATTRIBUTES = {
    :userid => {
      :type       => :string,
      :label      => N_('Subscription ID'),
      :help_text  => N_('The Subscription UUID for the Microsoft Azure Classic account'),
      :max_length => 1024,
      :required   => true
    }
  }.freeze

  EXTRA_ATTRIBUTES = {
    :ssh_key_data => {
      :type      => :password,
      :multiline => true,
      :label     => N_('Management Certificate'),
      :help_text => N_('Contents of the PEM file that corresponds to the certificate you uploaded in the Microsoft Azure console'),
      :required  => true
    }
  }.freeze

  API_ATTRIBUTES = COMMON_ATTRIBUTES.merge(EXTRA_ATTRIBUTES).freeze

  API_OPTIONS = {
    :type       => 'cloud',
    :label      => N_('Azure Classic (deprecated)'),
    :attributes => API_ATTRIBUTES
  }.freeze
  TOWER_KIND = 'azure'.freeze
end
