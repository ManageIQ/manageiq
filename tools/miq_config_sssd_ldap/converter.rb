module MiqConfigSssdLdap
  SSSD_CONF_FILE = "/etc/sssd/sssd.conf".freeze
  SSSD_ALREADY_CONFIGURED = "ERROR: #{SSSD_CONF_FILE} already exists. No changes will be made. Exiting".freeze

  class Converter
    attr_accessor :options, :initial_settings

    def initialize(args = {})
      self.options = args.delete_if { |_k, v| v.blank? }
      self.initial_settings = MiqLdapConfiguration.new(options).retrieve_initial_settings

      LOGGER.debug("#{File.basename(__FILE__)} - #{__method__} User provided settings: #{options}")
      LOGGER.debug("Initial Settings #{initial_settings}")
    end

    def run
      LOGGER.debug("Running #{$PROGRAM_NAME}")

      do_conversion unless initial_settings[:only_change_userids]
      ConfigureDatabase.new.change_userids_to_upn unless initial_settings[:skip_post_conversion_userid_change]

      Services.restart

      LOGGER.debug("#{$PROGRAM_NAME} Conversion Completed")
      puts("#{$PROGRAM_NAME} Conversion Completed")
    end

    private

    def do_conversion
      exit_if_sssd_is_already_configured
      AuthEstablish.new(initial_settings).run_auth_establish
      SssdConf.new(initial_settings).update
      disable_tls
      ConfigureApache.new(initial_settings).configure
      ConfigureSELinux.new(initial_settings).configure
      ConfigureApplianceSettings.new(initial_settings).configure
    end

    def disable_tls
      ConfigureSssdRules.disable_tls if initial_settings[:mode] == "ldap"
    end

    def exit_if_sssd_is_already_configured
      if File.exist?(SSSD_CONF_FILE)
        puts(SSSD_ALREADY_CONFIGURED)
        LOGGER.error(SSSD_ALREADY_CONFIGURED)
        exit
      end
    end
  end
end
