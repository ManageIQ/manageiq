class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::RhvCredential < ManageIQ::Providers::EmbeddedAnsible::AutomationManager::CloudCredential
  COMMON_ATTRIBUTES = {
    :userid   => {
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
      :label      => N_('Host'),
      :help_text  => N_('The host to authenticate with'),
      :max_length => 1024,
      :required   => true
    }
  }.freeze

  API_ATTRIBUTES = COMMON_ATTRIBUTES.merge(EXTRA_ATTRIBUTES).freeze

  API_OPTIONS = {
    :label      => N_('Red Hat Virtualization'),
    :type       => 'cloud',
    :attributes => API_ATTRIBUTES
  }.freeze

  def self.display_name(number = 1)
    n_('Credential (RHV)', 'Credentials (RHV)', number)
  end

  def self.params_to_attributes(params)
    attrs = params.dup
    attrs[:options] = { :host => attrs.delete(:host) } if attrs[:host]
    attrs
  end

  def host
    options && options[:host]
  end
end
