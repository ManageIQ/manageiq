class ManageIQ::Providers::Azure::CloudManager < ManageIQ::Providers::CloudManager
  require_dependency 'manageiq/providers/azure/cloud_manager/availability_zone'
  require_dependency 'manageiq/providers/azure/cloud_manager/flavor'
  require_dependency 'manageiq/providers/azure/cloud_manager/refresh_parser'
  require_dependency 'manageiq/providers/azure/cloud_manager/refresh_worker'
  require_dependency 'manageiq/providers/azure/cloud_manager/refresher'
  require_dependency 'manageiq/providers/azure/cloud_manager/vm'

  alias_attribute :azure_tenant_id, :uid_ems

  def self.ems_type
    @ems_type ||= "azure".freeze
  end

  def self.description
    @description ||= "Azure".freeze
  end

  def self.hostname_required?
    false
  end

  def self.raw_connect(clientid, clientkey, azuretenantid)
    ::Azure::Armrest::ArmrestService.configure(
      :client_id  => clientid,
      :client_key => clientkey,
      :tenant_id  => azuretenantid
    )
  end

  def connect(options = {})
    raise MiqException::MiqHostError, "No credentials defined" if self.missing_credentials?(options[:auth_type])

    clientid  = options[:user] || authentication_userid(options[:auth_type])
    clientkey = options[:pass] || authentication_password(options[:auth_type])
    self.class.raw_connect(clientid, clientkey, azure_tenant_id)
  end

  def verify_credentials(_auth_type = nil, options = {})
    connect(options)
  rescue RestClient::Unauthorized
    raise MiqException::MiqHostError, "Incorrect credentials - check your Azure Client ID and Client Key"
  rescue StandardError => err
    _log.error("Error Class=#{err.class.name}, Message=#{err.message}")
    raise MiqException::MiqHostError, "Unexpected response returned from system, see log for details"

    true
  end

  # Operations

  def vm_start(vm, _options = {})
    vm.provider_service.start(vm.name, vm.resource_group)
    vm.update_attributes!(:raw_power_state => "VM starting")
  rescue => err
    _log.error "vm=[#{vm.name}], error: #{err}"
  end

  def vm_stop(vm, _options = {})
    vm.provider_service.stop(vm.name, vm.resource_group)
    vm.update_attributes!(:raw_power_state => "VM stopping")
  rescue => err
    _log.error "vm=[#{vm.name}], error: #{err}"
  end

  def vm_restart(vm, _options = {})
    vm.provider_service.restart(vm.name, vm.resource_group)
    vm.update_attributes!(:raw_power_state => "VM starting")
  rescue => err
    _log.error "vm=[#{vm.name}], error: #{err}"
  end
end
