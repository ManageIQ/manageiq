class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::GoogleCredential < ManageIQ::Providers::EmbeddedAnsible::AutomationManager::CloudCredential
  COMMON_ATTRIBUTES = [
    {
      :component  => 'text-field',
      :label      => N_('Service Account Email Address'),
      :helperText => N_('The email address assigned to the Google Compute Engine service account'),
      :name       => 'userid',
      :id         => 'userid',
      :type       => 'email',
      :isRequired => true,
      :validate   => [{:type => 'required'}],
    },
  ].freeze

  EXTRA_ATTRIBUTES = [
    {
      :component      => 'password-field',
      :label          => N_('RSA Private Key'),
      :helperText     => N_('Contents of the PEM file associated with the service account email'),
      :componentClass => 'textarea',
      :name           => 'ssh_key_data',
      :id             => 'ssh_key_data',
      :type           => 'password',
      :isRequired     => true,
      :validate       => [{:type => 'required'}],
    },
    {
      :component  => 'text-field',
      :label      => N_('Project'),
      :helperText => N_('The GCE assigned identification. It is constructed as two words followed by a three digit number, such as: squeamish-ossifrage-123'),
      :name       => 'project',
      :id         => 'project',
      :maxLength  => 100,
    },
  ].freeze

  API_ATTRIBUTES = (COMMON_ATTRIBUTES + EXTRA_ATTRIBUTES).freeze

  API_OPTIONS = {
    :type       => 'cloud',
    :label      => N_('Google Compute Engine'),
    :attributes => API_ATTRIBUTES
  }.freeze

  alias ssh_key_data auth_key

  def self.display_name(number = 1)
    n_('Credential (Google)', 'Credentials (Google)', number)
  end

  def self.params_to_attributes(params)
    attrs = super.dup

    attrs[:auth_key] = attrs.delete(:ssh_key_data)            if attrs.key?(:ssh_key_data)
    attrs[:options]  = {:project => attrs.delete(:project)} if attrs[:project]

    attrs
  end

  def project
    options && options[:project]
  end
end
