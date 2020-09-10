class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::NetworkCredential < ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Credential
  COMMON_ATTRIBUTES = {
    :userid   => {
      :label     => N_('Username'),
      :help_text => N_('Username for this credential'),
      :required  => true
    },
    :password => {
      :type      => :password,
      :label     => N_('Password'),
      :help_text => N_('Password for this credential'),
      :required  => true
    }
  }.freeze

  # rubocop:disable Layout/AlignHash
  #
  # looks better to align the nested keys to the same distance, instead of
  # scope just for the hash in question (which is what rubocop does).
  EXTRA_ATTRIBUTES = {
    :authorize      => {
      :type         => :boolean,
      :label        => N_('Authorize'),
      :help_text    => N_('Whether to use the authorize mechanism')
    },
    :authorize_password => {
      :type         => :password,
      :label        => N_('Authorize password'),
      :help_text    => N_('Password used by the authorize mechanism')
    },
    :ssh_key_data   => {
      :type         => :password,
      :multiline    => true,
      :label        => N_('SSH key'),
      :help_text    => N_('RSA or DSA private key to be used instead of password')
    },
    :ssh_key_unlock => {
      :type         => :password,
      :label        => N_('Private key passphrase'),
      :help_text    => N_('Passphrase to unlock SSH private key if encrypted'),
      :max_length   => 1024
    }
  }.freeze
  # rubocop:enable Layout/AlignHash

  API_ATTRIBUTES = COMMON_ATTRIBUTES.merge(EXTRA_ATTRIBUTES).freeze

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
    attrs = params.dup

    attrs[:auth_key]          = attrs.delete(:ssh_key_data)       if attrs.key?(:ssh_key_data)
    attrs[:auth_key_password] = attrs.delete(:ssh_key_unlock)     if attrs.key?(:ssh_key_unlock)
    attrs[:become_password]   = attrs.delete(:authorize_password) if attrs.key?(:authorize_password)

    if attrs[:authorize]
      attrs[:options] = { :authorize => attrs.delete(:authorize) }
    end

    attrs
  end

  def authorize
    options && options[:authorize]
  end
end
