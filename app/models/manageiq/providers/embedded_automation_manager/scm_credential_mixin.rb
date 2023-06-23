module ManageIQ::Providers::EmbeddedAutomationManager::ScmCredentialMixin
  extend ActiveSupport::Concern

  included do
    const_set(
      :COMMON_ATTRIBUTES,
      [
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
    )

    const_set(
      :EXTRA_ATTRIBUTES,
      [
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
    )

    const_set(:API_ATTRIBUTES, (const_get(:COMMON_ATTRIBUTES) + const_get(:EXTRA_ATTRIBUTES)).freeze)
    const_set(:API_OPTIONS, {:label => N_('Scm'), :type => 'scm', :attributes => const_get(:API_ATTRIBUTES)}.freeze)

    alias_method :ssh_key_data, :auth_key
    alias_method :ssh_key_unlock, :auth_key_password

    before_validation :ensure_newline_for_ssh_key
  end

  class_methods do
    def display_name(number = 1)
      n_('Credential (SCM)', 'Credentials (SCM)', number)
    end

    def params_to_attributes(params)
      attrs = super.dup

      attrs[:auth_key]          = attrs.delete(:ssh_key_data)    if attrs.key?(:ssh_key_data)
      attrs[:auth_key_password] = attrs.delete(:ssh_key_unlock)  if attrs.key?(:ssh_key_unlock)

      attrs
    end
  end
end
