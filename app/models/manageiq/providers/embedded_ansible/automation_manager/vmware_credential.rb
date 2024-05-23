class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::VmwareCredential < ManageIQ::Providers::EmbeddedAnsible::AutomationManager::CloudCredential
  COMMON_ATTRIBUTES = [
    {
      :component  => 'text-field',
      :label      => N_('Username'),
      :helperText => N_('Username for this credential'),
      :name       => 'userid',
      :id         => 'userid',
      :isRequired => true,
      :validate   => [{:type => 'required'}],
    },
    {
      :component  => 'password-field',
      :label      => N_('Password'),
      :helperText => N_('Password for this credential'),
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
      :label      => N_('vCenter Host'),
      :helperText => N_('The hostname or IP address of the vCenter Host'),
      :name       => 'host',
      :id         => 'host',
      :maxLength  => 1024,
      :isRequired => true,
      :validate   => [{:type => 'required'}],
    },
  ].freeze

  API_ATTRIBUTES = (COMMON_ATTRIBUTES + EXTRA_ATTRIBUTES).freeze

  API_OPTIONS = {
    :label      => N_('VMware'),
    :type       => 'cloud',
    :attributes => API_ATTRIBUTES
  }.freeze

  def self.display_name(number = 1)
    n_('Credential (VMware)', 'Credentials (VMware)', number)
  end

  def self.params_to_attributes(params)
    attrs = super.dup
    attrs[:options] = {:host => attrs.delete(:host)} if attrs[:host]
    attrs
  end

  def host
    options && options[:host]
  end
end
