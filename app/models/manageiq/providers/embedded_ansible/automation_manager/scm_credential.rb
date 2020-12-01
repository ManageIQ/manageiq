class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::ScmCredential < ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Credential
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

  # rubocop:disable Layout/AlignHash
  #
  # looks better to align the nested keys to the same distance, instead of
  # scope just for the hash in question (which is what rubocop does.
  EXTRA_ATTRIBUTES = {
    :ssh_key_unlock => {
      :type       => :password,
      :label      => N_('Private key passphrase'),
      :help_text  => N_('Passphrase to unlock SSH private key if encrypted'),
      :max_length => 1024
    },
    :ssh_key_data => {
      :type       => :password,
      :multiline  => true,
      :label      => N_('Private key'),
      :help_text  => N_('RSA or DSA private key to be used instead of password')
    }
  }.freeze
  # rubocop:enable Layout/AlignHash

  API_ATTRIBUTES = COMMON_ATTRIBUTES.merge(EXTRA_ATTRIBUTES).freeze

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
