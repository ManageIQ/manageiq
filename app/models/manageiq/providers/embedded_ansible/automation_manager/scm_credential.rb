class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::ScmCredential < ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Credential
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
      :component      => 'password-field',
      :label          => N_('Private key'),
      :helperText     => N_('RSA or DSA private key to be used instead of password'),
      :componentClass => 'textarea',
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
      :maxLength  => 1024,
      :type       => 'password',
    },
  ].freeze

  API_ATTRIBUTES = (COMMON_ATTRIBUTES + EXTRA_ATTRIBUTES).freeze

  API_OPTIONS = {
    :label      => N_('Scm'),
    :type       => 'scm',
    :attributes => API_ATTRIBUTES
  }.freeze

  alias ssh_key_data   auth_key
  alias ssh_key_unlock auth_key_password

  before_validation :ensure_newline_for_ssh_key

  def self.display_name(number = 1)
    n_('Credential (SCM)', 'Credentials (SCM)', number)
  end

  def self.params_to_attributes(params)
    attrs = params.dup

    attrs[:auth_key]          = attrs.delete(:ssh_key_data)    if attrs.key?(:ssh_key_data)
    attrs[:auth_key_password] = attrs.delete(:ssh_key_unlock)  if attrs.key?(:ssh_key_unlock)

    attrs
  end
end
