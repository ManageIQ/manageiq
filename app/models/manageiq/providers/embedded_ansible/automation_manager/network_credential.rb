class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::NetworkCredential < ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Credential
  COMMON_ATTRIBUTES = [
    {
      :component  => 'text-field',
      :label      => N_('Username'),
      :helperText => N_('Username for this credential'),
      :name       => 'userid',
      :id         => 'userid',
      :isRequired => true,
      :validate   => [{:type => 'required'}],
    },
    {
      :component  => 'password-field',
      :label      => N_('Password'),
      :helperText => N_('Password for this credential'),
      :name       => 'password',
      :id         => 'password',
      :type       => 'password',
      :isRequired => true,
      :validate   => [{:type => 'required'}],
    },
  ].freeze

  EXTRA_ATTRIBUTES = [
    {
      :component  => 'switch',
      :label      => N_('Authorize'),
      :helperText => N_('Whether to use the authorize mechanism'),
      :name       => 'authorize',
      :id         => 'authorize',
      :onText     => 'Yes',
      :offText    => 'No',
      :type       => 'boolean',
    },
    {
      :component  => 'password-field',
      :label      => N_('Authorize password'),
      :helperText => N_('Password used by the authorize mechanism'),
      :name       => 'authorize_password',
      :id         => 'authorize_password',
      :type       => 'password',
    },
    {
      :component      => 'password-field',
      :label          => N_('SSH key'),
      :componentClass => 'textarea',
      :helperText     => N_('RSA or DSA private key to be used instead of password'),
      :name           => 'ssh_key_data',
      :id             => 'ssh_key_data',
      :type           => 'password',
    },
    {
      :component  => 'password-field',
      :label      => N_('Private key passphrase'),
      :helperText => N_('Passphrase to unlock SSH private key if encrypted'),
      :name       => 'ssh_key_unlock',
      :id         => 'ssh_key_unlock',
      :type       => 'password',
      :maxLength  => 1024,
    },
  ].freeze

  API_ATTRIBUTES = (COMMON_ATTRIBUTES + EXTRA_ATTRIBUTES).freeze

  API_OPTIONS = {
    :label      => N_('Network'),
    :type       => 'network',
    :attributes => API_ATTRIBUTES
  }.freeze

  alias ssh_key_data       auth_key
  alias ssh_key_unlock     auth_key_password
  alias authorize_password become_password

  def self.display_name(number = 1)
    n_('Credential (Network)', 'Credentials (Network)', number)
  end

  def self.params_to_attributes(params)
    attrs = super.dup

    attrs[:auth_key]          = attrs.delete(:ssh_key_data)       if attrs.key?(:ssh_key_data)
    attrs[:auth_key_password] = attrs.delete(:ssh_key_unlock)     if attrs.key?(:ssh_key_unlock)
    attrs[:become_password]   = attrs.delete(:authorize_password) if attrs.key?(:authorize_password)

    if attrs[:authorize]
      attrs[:options] = {:authorize => attrs.delete(:authorize)}
    end

    attrs
  end

  def authorize
    options && options[:authorize]
  end
end
