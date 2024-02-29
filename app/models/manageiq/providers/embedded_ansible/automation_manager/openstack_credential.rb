class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::OpenstackCredential < ManageIQ::Providers::EmbeddedAnsible::AutomationManager::CloudCredential
  COMMON_ATTRIBUTES = [
    {
      :component  => 'text-field',
      :label      => N_('Username'),
      :helperText => N_('The username to use to connect to OpenStack'),
      :name       => 'userid',
      :id         => 'userid',
      :isRequired => true,
      :validate   => [{:type => 'required'}],
    },
    {
      :component  => 'password-field',
      :label      => N_('Password (API Key)'),
      :helperText => N_('The password or API key to use to connect to OpenStack'),
      :name       => 'password',
      :id         => 'password',
      :type       => 'password',
      :isRequired => true,
      :validate   => [{:type => 'required'}],
    },
  ].freeze

  EXTRA_ATTRIBUTES = [
    {
      :component  => 'text-field',
      :label      => N_('Host (Authentication URL)'),
      :helperText => N_('The host to authenticate with. For example, https://openstack.business.com/v2.0'),
      :name       => 'host',
      :id         => 'host',
      :maxLength  => 1024,
      :isRequired => true,
      :validate   => [{:type => 'required'}],
    },
    {
      :component  => 'text-field',
      :label      => N_('Project (Tenant Name)'),
      :helperText => N_('This is the tenant name. This value is usually the same as the username'),
      :name       => 'project',
      :id         => 'project',
      :maxLength  => 100,
      :isRequired => true,
      :validate   => [{:type => 'required'}],
    },
    {
      :component  => 'text-field',
      :label      => N_('Domain Name'),
      :helperText => N_('OpenStack domains define administrative boundaries. It is only needed for Keystone v3 authentication URLs'),
      :name       => 'domain',
      :id         => 'domain',
      :maxLength  => 100,
    },
  ].freeze

  API_ATTRIBUTES = (COMMON_ATTRIBUTES + EXTRA_ATTRIBUTES).freeze

  API_OPTIONS = {
    :type       => 'cloud',
    :label      => N_('OpenStack'),
    :attributes => API_ATTRIBUTES
  }.freeze

  def self.display_name(number = 1)
    n_('Credential (OpenStack)', 'Credentials (OpenStack)', number)
  end

  def self.params_to_attributes(params)
    attrs = super.dup

    if %i[host domain project].any? { |opt| attrs.has_key? opt }
      attrs[:options]         ||= {}
      attrs[:options][:host]    = attrs.delete(:host)    if attrs.key?(:host)
      attrs[:options][:domain]  = attrs.delete(:domain)  if attrs.key?(:domain)
      attrs[:options][:project] = attrs.delete(:project) if attrs.key?(:project)
    end

    attrs
  end

  def host
    options && options[:host]
  end

  def domain
    options && options[:domain]
  end

  def project
    options && options[:project]
  end
end
