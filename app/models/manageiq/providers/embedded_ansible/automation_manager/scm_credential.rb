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

  # rubocop:disable Layout/AlignHash
  #
  # looks better to align the nested keys to the same distance, instead of
  # scope just for the hash in question (which is what rubocop does.
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
  # rubocop:enable Layout/AlignHash

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

  private

  def ensure_newline_for_ssh_key
    self.auth_key = "#{auth_key}\n" if auth_key.present? && auth_key[-1] != "\n"
  end
end
