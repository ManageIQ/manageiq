$LOAD_PATH << File.join(GEMS_PENDING_ROOT, "Scvmm")

class ManageIQ::Providers::Microsoft::InfraManager::Host < ::Host
  def verify_credentials(auth_type = nil, _options = {})
    raise MiqException::MiqHostError "No credentials defined" if missing_credentials?(auth_type)
    verify_credentials_windows(hostname, *auth_user_pwd(auth_type))
  end

  def verify_credentials_windows(server = nil, username = nil, password = nil, _namespace = nil)
    require 'miq_winrm'
    log_header = "MIQ(#{self.class.name}.#{__method__})"
    begin
      winrm              = MiqWinRM.new
      options            = {}
      options[:user]     = username
      options[:pass]     = password
      options[:hostname] = server
      $scvmm_log.info("#{log_header} Verifying credentials for hostname #{server}")
      connection = winrm.connect(options)
      connection.run_powershell_script("hostname")
    rescue WinRM::WinRMHTTPTransportError => e
      raise MiqException::MiqHostError, "Check credentials and WinRM configuration settings. " \
      "Remote error message: #{e.message}"
    rescue WinRM::WinRMAuthorizationError => e
      raise MiqException::MiqHostError, "Check credentials. Remote error message: #{e.message}"
    rescue StandardError => e
      raise MiqException::MiqHostError, "Unable to connect: #{e.message}."
    end
    true
  end
end
