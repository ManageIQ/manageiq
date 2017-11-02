require 'linux_admin'

module MiqServer::NtpManagement
  extend ActiveSupport::Concern

  def ntp_config
    get_config("vmdb").config[:ntp]
  end

  def server_ntp_settings_blank?(ntp)
    # verify the ntp settings are like this and not blank:  {:ntp => {:server => ['blah'], :timeout => 5}}
    ntp.values.flatten.compact.blank? rescue true
  end

  # Called when zone ntp settings changed... run by the appropriate server
  # Also, called in start of miq_server and on a configuration change for the server
  def ntp_reload(ntp_settings = ntp_config)
    # matches ntp_reload_queue's guard clause
    return if !MiqEnvironment::Command.is_appliance? || MiqEnvironment::Command.is_container?

    if @ntp_settings && @ntp_settings == ntp_settings
      _log.info("Skipping reload of ntp settings since they are unchanged")
      return
    end

    unless ntp_settings.kind_of?(Hash)
      _log.warn("NTP settings, expected hash, received: #{ntp_settings.class}, #{ntp_settings.inspect}")
      return
    end

    _log.info("Synchronizing ntp settings: #{ntp_settings.inspect}")
    apply_ntp_server_settings(ntp_settings)
    @ntp_settings = ntp_settings
  end

  private

  def apply_ntp_server_settings(settings)
    chrony_conf = LinuxAdmin::Chrony.new
    chrony_conf.clear_servers

    servers = settings[:server]
    servers = [servers] unless servers.kind_of?(Array)
    chrony_conf.add_servers(*servers)
  end
end
