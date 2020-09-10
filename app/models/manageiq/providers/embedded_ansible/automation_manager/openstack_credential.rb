class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::OpenstackCredential < ManageIQ::Providers::EmbeddedAnsible::AutomationManager::CloudCredential
  COMMON_ATTRIBUTES = {
    :userid   => {
      :label     => N_('Username'),
      :help_text => N_('The username to use to connect to OpenStack'),
      :required  => true
    },
    :password => {
      :type      => :password,
      :label     => N_('Password (API Key)'),
      :help_text => N_('The password or API key to use to connect to OpenStack'),
      :required  => true
    }
  }.freeze

  EXTRA_ATTRIBUTES = {
    :host    => {
      :type       => :string,
      :label      => N_('Host (Authentication URL)'),
      :help_text  => N_('The host to authenticate with. For example, https://openstack.business.com/v2.0'),
      :max_length => 1024,
      :required   => true
    },
    :project => {
      :type       => :string,
      :label      => N_('Project (Tenant Name)'),
      :help_text  => N_('This is the tenant name. This value is usually the same as the username'),
      :max_length => 100,
      :required   => true
    },
    :domain  => {
      :type       => :string,
      :label      => N_('Domain Name'),
      :help_text  => N_('OpenStack domains define administrative boundaries. It is only needed for Keystone v3 authentication URLs'),
      :max_length => 100
    }
  }.freeze

  API_ATTRIBUTES = COMMON_ATTRIBUTES.merge(EXTRA_ATTRIBUTES).freeze

  API_OPTIONS = {
    :type       => 'cloud',
    :label      => N_('OpenStack'),
    :attributes => API_ATTRIBUTES
  }.freeze

  def self.display_name(number = 1)
    n_('Credential (OpenStack)', 'Credentials (OpenStack)', number)
  end

  def self.params_to_attributes(params)
    attrs = params.dup

    if %i[host domain project].any? {|opt| attrs.has_key? opt }
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
