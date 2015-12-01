require 'linux_admin'

module MiqServer::NtpManagement
  extend ActiveSupport::Concern

  def server_ntp_settings
    # Get the ntp servers from the vmdb.yml first, zone second, else use some defaults
    ntp = ntp_config
    if server_ntp_settings_blank?(ntp)
      zone.ntp_settings
    else
      ntp.merge!(:source => :server)
      ntp
    end
  end

  def ntp_config
    get_config("vmdb").config[:ntp]
  end

  def server_ntp_settings_blank?(ntp)
    # verify the ntp settings are like this and not blank:  {:ntp => {:server => ['blah'], :timeout => 5}}
    ntp.values.flatten.compact.blank? rescue true
  end

  # Called when zone ntp settings changed... run by the appropriate server
  # Also, called in atStartup of miq_server and on a configuration change for the server
  def ntp_reload(ntp_settings = server_ntp_settings)
    if @ntp_settings && @ntp_settings == ntp_settings
      _log.info("Skipping reload of ntp settings since they are unchanged")
      return
    end

    unless ntp_settings.kind_of?(Hash)
      _log.warn("NTP settings, expected hash, received: #{ntp_settings.class}, #{ntp_settings.inspect}")
      return
    end

    if ntp_settings.delete(:source) != :server && !server_ntp_settings_blank?(ntp_config)
      _log.info("Skipping reload of ntp settings from zone since this server is configured with it's own ntp settings")
      return
    end

    if ntp_settings[:server].nil?
      _log.warn("No ntp server settings to synchronize")
      return
    end
    _log.info("Synchronizing ntp settings: #{ntp_settings.inspect}")
    apply_ntp_server_settings(ntp_settings)
    @ntp_settings = ntp_settings
  end

  def apply_ntp_server_settings(settings)
    return unless Sys::Platform::IMPL == :linux

    chrony_conf = LinuxAdmin::Chrony.new
    chrony_conf.clear_servers

    servers = settings[:server]
    servers = [servers] unless servers.kind_of?(Array)
    chrony_conf.add_servers(*servers)
  end
end
