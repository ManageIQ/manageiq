class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::VaultCredential < ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Credential
  COMMON_ATTRIBUTES = [].freeze

  EXTRA_ATTRIBUTES = [
    {
      :component  => 'password-field',
      :label      => N_('Vault password'),
      :helperText => N_('Vault password'),
      :name       => 'vault_password',
      :id         => 'vault_password',
      :maxLength  => 1024,
      :type       => 'password',
    },
  ].freeze

  API_ATTRIBUTES = (COMMON_ATTRIBUTES + EXTRA_ATTRIBUTES).freeze

  API_OPTIONS = {
    :label      => N_('Vault'),
    :type       => 'vault',
    :attributes => API_ATTRIBUTES
  }.freeze

  def self.display_name(number = 1)
    n_('Credential (Vault)', 'Credentials (Vault)', number)
  end

  alias vault_password password

  def self.params_to_attributes(params)
    attrs = super.dup
    attrs[:password] = attrs.delete(:vault_password) if attrs.key?(:vault_password)
    attrs
  end
end
