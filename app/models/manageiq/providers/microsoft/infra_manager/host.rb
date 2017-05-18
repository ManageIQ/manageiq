class ManageIQ::Providers::Microsoft::InfraManager::Host < ::Host
  def verify_credentials(auth_type = nil, _options = {})
    raise MiqException::MiqHostError "No credentials defined" if missing_credentials?(auth_type)
    options                            = {}
    options[:user], options[:password] = auth_user_pwd(auth_type)
    options[:hostname]                 = hostname
    verify_credentials_windows(options)
  end

  def verify_credentials_windows(options)
    require 'miq_winrm'
    $scvmm_log.info "MIQ(#{self.class.name}.#{__method__}) Verifying credentials for hostname #{options[:hostname]}"
    begin
      winrm = MiqWinRM.new
      winrm.connect(options).shell(:powershell).run("hostname")
    rescue WinRM::WinRMHTTPTransportError => e
      raise MiqException::MiqHostError, "Check credentials and WinRM configuration settings. " \
      "Remote error message: #{e.message}"
    rescue WinRM::WinRMAuthorizationError => e
      raise MiqException::MiqHostError, "Check credentials. Remote error message: #{e.message}"
    rescue => e
      raise MiqException::MiqHostError, "Unable to connect: #{e.message}."
    end
    true
  end

  def host_handle
    require 'Scvmm/miq_scvmm_vm_ssa_info'

    auth_type = nil
    user, pass = auth_user_pwd(auth_type)
    MiqScvmmVmSSAInfo.new(hostname, user, pass)
  end
end
