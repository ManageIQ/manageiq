class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::AzureCredential < ManageIQ::Providers::EmbeddedAnsible::AutomationManager::CloudCredential
  COMMON_ATTRIBUTES = [
    {
      :component  => 'text-field',
      :label      => N_('Username'),
      :helperText => N_('The username to use to connect to the Microsoft Azure account'),
      :name       => 'userid',
      :id         => 'userid',
    },
    {
      :component  => 'password-field',
      :label      => N_('Password'),
      :helperText => N_('The password to use to connect to the Microsoft Azure account'),
      :name       => 'password',
      :id         => 'password',
      :type       => 'password',
    },
  ].freeze

  EXTRA_ATTRIBUTES = [
    {
      :component  => 'text-field',
      :label      => N_('Subscription ID'),
      :helperText => N_('The Subscription ID for the Microsoft Azure account'),
      :name       => 'subscription',
      :id         => 'subscription',
      :isRequired => true,
      :validate   => [{:type => 'required'}],
    },
    {
      :component  => 'text-field',
      :label      => N_('Tenant ID'),
      :helperText => N_('The Tenant ID for the Microsoft Azure account'),
      :name       => 'tenant',
      :id         => 'tenant',
      :maxLength  => 1024,
    },
    {
      :component  => 'password-field',
      :label      => N_('Client Secret'),
      :helperText => N_('The Client Secret for the Microsoft Azure account'),
      :name       => 'secret',
      :id         => 'secret',
      :type       => 'password',
      :maxLength  => 1024,
    },
    {
      :component  => 'text-field',
      :label      => N_('Client ID'),
      :helperText => N_('The Client ID for the Microsoft Azure account'),
      :name       => 'client',
      :id         => 'client',
      :maxLength  => 128,
    },
  ].freeze

  API_ATTRIBUTES = (COMMON_ATTRIBUTES + EXTRA_ATTRIBUTES).freeze

  API_OPTIONS = {
    :type       => 'cloud',
    :label      => N_('Azure'),
    :attributes => API_ATTRIBUTES
  }.freeze

  alias secret auth_key

  def self.display_name(number = 1)
    n_('Credential (Microsoft Azure)', 'Credentials (Microsoft Azure)', number)
  end

  def self.params_to_attributes(params)
    attrs            = super.dup
    attrs[:auth_key] = attrs.delete(:secret) if attrs.key?(:secret)

    if %i[client tenant subscription].any? { |opt| attrs.has_key? opt }
      attrs[:options]              ||= {}
      attrs[:options][:client]       = attrs.delete(:client)       if attrs.key?(:client)
      attrs[:options][:tenant]       = attrs.delete(:tenant)       if attrs.key?(:tenant)
      attrs[:options][:subscription] = attrs.delete(:subscription) if attrs.key?(:subscription)
    end

    attrs
  end

  def client
    options && options[:client]
  end

  def tenant
    options && options[:tenant]
  end

  def subscription
    options && options[:subscription]
  end
end
