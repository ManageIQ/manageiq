class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::VaultCredential < ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Credential
  COMMON_ATTRIBUTES = {}.freeze

  EXTRA_ATTRIBUTES = {
    :vault_password => {
      :type       => :password,
      :label      => N_('Vault password'),
      :help_text  => N_('Vault password'),
      :max_length => 1024
    }
  }.freeze

  API_ATTRIBUTES = COMMON_ATTRIBUTES.merge(EXTRA_ATTRIBUTES).freeze

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
    attrs = params.dup
    attrs[:password] = attrs.delete(:vault_password) if attrs.key?(:vault_password)
    attrs
  end
end
