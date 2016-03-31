class ManageIQ::Providers::Microsoft::InfraManager < ManageIQ::Providers::InfraManager
  require_nested :Host
  require_nested :Provision
  require_nested :ProvisionWorkflow
  require_nested :Refresher
  require_nested :RefreshParser
  require_nested :RefreshWorker
  require_nested :Template
  require_nested :Vm

  include_concern "Powershell"

  def self.ems_type
    @ems_type ||= "scvmm".freeze
  end

  def self.description
    @description ||= "Microsoft System Center VMM".freeze
  end

  def self.raw_connect(auth_url, security_protocol, connect_params)
    # HACK: WinRM depends on the gssapi gem for encryption purposes.
    # The gssapi code outputs the following warning:
    #   WARNING: Could not load IOV methods. Check your GSSAPI C library for an update
    #   WARNING: Could not load AEAD methods. Check your GSSAPI C library for an update
    # This warning is considered benign and can be ignored.
    # Please note - the webmock gem depends on gssapi too and prints out the
    # above warning when rspec tests are run.

    silence_warnings { require 'winrm' }

    winrm = WinRM::WinRMWebService.new(auth_url, security_protocol.to_sym, connect_params)
    winrm.set_timeout(1800)
    winrm
  end

  def self.auth_url(hostname, port = nil)
    URI::HTTP.build(:host => hostname, :port => port || 5985, :path => "/wsman").to_s
  end

  def connect(options = {})
    raise "no credentials defined" if self.missing_credentials?(options[:auth_type])

    hostname       = options[:hostname] || self.hostname
    auth_url       = self.class.auth_url(hostname, port)
    connect_params = build_connect_params(options)

    self.class.raw_connect(auth_url, security_protocol, connect_params)
  end

  def verify_credentials(_auth_type = nil, options = {})
    silence_warnings { require 'winrm' }
    silence_warnings { require 'gssapi' } # Version 1.0.0 of the gssapi gem emits warnings

    raise MiqException::MiqHostError, "No credentials defined" if self.missing_credentials?(options[:auth_type])

    begin
      run_dos_command("hostname")
    rescue WinRM::WinRMHTTPTransportError => e # Error 401
      raise MiqException::MiqHostError, "Check credentials and WinRM configuration settings. " \
      "Remote error message: #{e.message}"
    rescue GSSAPI::GssApiError
      raise MiqException::MiqHostError, "Unable to reach any KDC in realm #{realm}"
    rescue StandardError => e
      raise MiqException::MiqHostError, "Unable to connect: #{e.message}"
    end

    true
  end

  def vm_start(vm, _options = {})
    case vm.power_state
    when "suspended" then execute_power_operation("Resume", vm.uid_ems)
    when "off"       then execute_power_operation("Start", vm.uid_ems)
    end
  end

  def vm_stop(vm, _options = {})
    execute_power_operation("Stop", vm.uid_ems, "-Force")
  end

  def vm_shutdown_guest(vm, _options = {})
    execute_power_operation("Stop", vm.uid_ems, "-Shutdown")
  end

  def vm_reset(vm, _options = {})
    execute_power_operation("Reset", vm.uid_ems)
  end

  def vm_reboot_guest(vm, _options = {})
    execute_power_operation("Stop", vm.uid_ems, "-Shutdown")
    execute_power_operation("Start", vm.uid_ems)
  end

  def vm_suspend(vm, _options = {})
    execute_power_operation("Suspend", vm.uid_ems)
  end

  def vm_resume(vm, _options = {})
    execute_power_operation("Resume", vm.uid_ems)
  end

  def vm_destroy(vm, _options = {})
    vm_stop(vm)
    execute_power_operation("Remove", vm.uid_ems)
  end

  def vm_create_evm_snapshot(vm, _options)
    log_prefix = "vm_create_evm_snapshot: vm=[#{vm.name}]"

    host_handle = vm.host.host_handle
    host_handle.vm_create_evm_checkpoint(vm.name)
  rescue => err
    $scvmm_log.error "#{log_prefix}, error: #{err}"
    $scvmm_log.debug { err.backtrace.join("\n") }
    raise
  end

  def vm_delete_evm_snapshot(vm, _options)
    log_prefix = "vm_delete_evm_snapshot: vm=[#{vm.name}]"

    host_handle = vm.host.host_handle
    host_handle.vm_remove_evm_checkpoint(vm.name)
  rescue => err
    $scvmm_log.error "#{log_prefix}, error: #{err}"
    $scvmm_log.debug { err.backtrace.join("\n") }
    raise
  end

  private

  def execute_power_operation(cmdlet, vm_uid_ems, *parameters)
    return unless vm_uid_ems.guid?

    params  = parameters.join(" ")

    # TODO: If localhost could feasibly be changed to an IPv6 address such as "::1", we need to
    # wrap the IPv6 address in square brackets,  similar to the a URIs's host field, "[::1]".
    command = "powershell Import-Module VirtualMachineManager; Get-SCVMMServer localhost;\
      #{cmdlet}-SCVirtualMachine -VM (Get-SCVirtualMachine -ID #{vm_uid_ems}) #{params}"
    run_dos_command(command)
  end

  def build_connect_params(options)
    connect_params  = {
      :user         => options[:user] || authentication_userid(options[:auth_type]),
      :pass         => options[:pass] || authentication_password(options[:auth_type]),
      :disable_sspi => true
    }

    if security_protocol == "kerberos"
      connect_params.merge!(
        :realm           => realm,
        :basic_auth_only => false,
        :disable_sspi    => false
      )
    end

    connect_params
  end
end
