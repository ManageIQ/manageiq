
$:.push(File.expand_path(File.join(Rails.root, %w{.. lib Scvmm})))

class EmsMicrosoft < EmsInfra
  include_concern "Powershell"
  include ScvmmErrorHandling

  def self.ems_type
    @ems_type ||= "scvmm".freeze
  end

  def self.description
    @description ||= "Microsoft System Center VMM".freeze
  end

  def self.raw_connect(username, password, auth_url)
    # HACK: WinRM depends on the gssapi gem for encryption purposes.
    # The gssapi code outputs the following warning:
    #   WARNING: Could not load IOV methods. Check your GSSAPI C library for an update
    #   WARNING: Could not load AEAD methods. Check your GSSAPI C library for an update
    # After much googling, this warning is considered benign and can be ignored.
    # Please note - the webmock gem depends on gssapi too and prints out the
    # above warning when rspec tests are run.
    silence_warnings { require 'winrm' }

    WinRM::WinRMWebService.new(auth_url, :ssl, :user => username, :pass => password, :disable_sspi => true)
  end

  def self.auth_url(hostname, port = nil)
    URI::HTTP.build(:host => hostname, :port => port || 5985, :path => "/wsman").to_s
  end

  def connect(options = {})
    raise "no credentials defined" if self.missing_credentials?(options[:auth_type])

    username = options[:user] || authentication_userid(options[:auth_type])
    password = options[:pass] || authentication_password(options[:auth_type])
    hostname = options[:hostname] || self.hostname
    auth_url = self.class.auth_url(hostname, port)
    self.class.raw_connect(username, password, auth_url)
  end

  def verify_credentials(_auth_type = nil, options = {})
    raise MiqException::MiqHostError, "No credentials defined" if self.missing_credentials?(options[:auth_type])

    begin
      run_dos_command("powershell import-module virtualmachinemanager; \
        Get-SCVMMServer -ComputerName localhost")

    rescue ScvmmNotInstalled => e
      raise MiqException::MiqHostError, "#{e.message}"

    rescue WinRM::WinRMHTTPTransportError => e # Error 401
      raise MiqException::MiqHostError, "Check credentials and WinRM configuration
        settings. Remote error message: #{e.message}"

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

  private

  def execute_power_operation(cmdlet, vm_uid_ems, *parameters)
    return unless vm_uid_ems.guid?

    params  = parameters.join(" ")
    command = "powershell #{cmdlet}-SCVirtualMachine -VM (Get-SCVirtualMachine -ID #{vm_uid_ems}) #{params}"
    run_dos_command(command)
  end
end
