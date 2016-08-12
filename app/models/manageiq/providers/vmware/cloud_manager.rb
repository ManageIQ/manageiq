class ManageIQ::Providers::Vmware::CloudManager < ManageIQ::Providers::CloudManager
  require_nested :OrchestrationStack
  require_nested :OrchestrationTemplate
  require_nested :RefreshParser
  require_nested :RefreshWorker
  require_nested :Refresher
  require_nested :Template
  require_nested :Vm

  include ManageIQ::Providers::Vmware::ManagerAuthMixin

  def self.ems_type
    @ems_type ||= "vmware_cloud".freeze
  end

  def self.description
    @description ||= "VMware vCloud".freeze
  end

  def self.default_blacklisted_event_names
    []
  end

  def self.hostname_required?
    true
  end

  def supports_port?
    true
  end

  def supported_auth_types
    %w(default)
  end

  def supports_authentication?(authtype)
    supported_auth_types.include?(authtype.to_s)
  end

  #
  # Operations
  #

  def vm_start(vm, _options = {})
    vm.start
  rescue => err
    _log.error "vm=[#{vm.name}, error: #{err}"
  end

  def vm_stop(vm, _options = {})
    vm.stop
  rescue => err
    _log.error "vm=[#{vm.name}, error: #{err}"
  end

  def vm_suspend(vm, _options = {})
    vm.suspend
  rescue => err
    _log.error "vm=[#{vm.name}], error: #{err}"
  end

  def vm_restart(vm, _options = {})
    vm.restart
  rescue => err
    _log.error "vm=[#{vm.name}], error: #{err}"
  end

  def translate_exception(err)
    case err
    when Fog::Compute::VcloudDirector::Unauthorized
      MiqException::MiqInvalidCredentialsError.new "Login failed due to a bad username or password."
    else
      MiqException::MiqHostError.new "Unexpected response returned from system: #{err.message}"
    end
  end
end
