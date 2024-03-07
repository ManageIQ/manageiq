class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::RhvCredential < ManageIQ::Providers::EmbeddedAnsible::AutomationManager::CloudCredential
  COMMON_ATTRIBUTES = [
    {
      :component  => 'text-field',
      :label      => N_('Username'),
      :helperText => N_('Username for this credential'),
      :name       => 'userid',
      :id         => 'userid',
    },
    {
      :component  => 'password-field',
      :label      => N_('Password'),
      :helperText => N_('Password for this credential'),
      :name       => 'password',
      :id         => 'password',
      :type       => 'password',
    },
  ].freeze

  EXTRA_ATTRIBUTES = [
    {
      :component  => 'text-field',
      :label      => N_('Host'),
      :helperText => N_('The host to authenticate with'),
      :name       => 'host',
      :id         => 'host',
      :maxLength  => 1024,
      :isRequired => true,
      :validate   => [{:type => 'required'}],
    },
  ].freeze

  API_ATTRIBUTES = (COMMON_ATTRIBUTES + EXTRA_ATTRIBUTES).freeze

  API_OPTIONS = {
    :label      => N_('Red Hat Virtualization'),
    :type       => 'cloud',
    :attributes => API_ATTRIBUTES
  }.freeze

  def self.display_name(number = 1)
    n_('Credential (RHV)', 'Credentials (RHV)', number)
  end

  def self.params_to_attributes(params)
    attrs = super.dup
    attrs[:options] = {:host => attrs.delete(:host)} if attrs[:host]
    attrs
  end

  def host
    options && options[:host]
  end
end
