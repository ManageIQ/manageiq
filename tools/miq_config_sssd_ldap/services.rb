require 'linux_admin'

module MiqConfigSssdLdap
  class Services
    def self.restart
      LOGGER.debug("Invoked #{self.class}\##{__method__}")

      LOGGER.debug("\nRestarting httpd, if running ...")
      httpd_service = LinuxAdmin::Service.new("httpd")
      httpd_service.restart if httpd_service.running?

      LOGGER.debug("Restarting sssd and configure it to start on reboots ...")
      sssd_service = LinuxAdmin::Service.new("sssd")
      sssd_service.restart.enable if sssd_service.running?

      LOGGER.debug("Restarting evmserverd and configure it to start on reboots ...")
      evmserverd_service = LinuxAdmin::Service.new("evmserverd")
      evmserverd_service.restart.enable if evmserverd_service.running?
    end
  end
end
