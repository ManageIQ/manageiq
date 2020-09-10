class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::GoogleCredential < ManageIQ::Providers::EmbeddedAnsible::AutomationManager::CloudCredential
  COMMON_ATTRIBUTES = {
    :userid => {
      :type      => :email,
      :label     => N_('Service Account Email Address'),
      :help_text => N_('The email address assigned to the Google Compute Engine service account'),
      :required  => true
    }
  }.freeze

  # rubocop:disable Layout/AlignHash
  #
  # looks better to align the nested keys to the same distance, instead of
  # scope just for the hash in question (which is what rubocop does.
  EXTRA_ATTRIBUTES = {
    :ssh_key_data => {
      :type       => :password,
      :multiline  => true,
      :label      => N_('RSA Private Key'),
      :help_text  => N_('Contents of the PEM file associated with the service account email'),
      :required   => true
    },
    :project      => {
      :type       => :string,
      :label      => N_('Project'),
      :help_text  => N_('The GCE assigned identification. It is constructed as two words followed by a three digit number, such as: squeamish-ossifrage-123'),
      :max_length => 100,
    }
  }.freeze
  # rubocop:enable Layout/AlignHash

  API_ATTRIBUTES = COMMON_ATTRIBUTES.merge(EXTRA_ATTRIBUTES).freeze

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
    attrs = params.dup

    attrs[:auth_key] = attrs.delete(:ssh_key_data)            if attrs.key?(:ssh_key_data)
    attrs[:options]  = { :project => attrs.delete(:project) } if attrs[:project]

    attrs
  end

  def project
    options && options[:project]
  end
end
