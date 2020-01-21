require 'fileutils'

module MiqConfigSssdLdap
  class ConfigureSssdRulesError < StandardError; end

  class ConfigureSssdRules
    CFG_RULES_FILE = "/usr/share/sssd/cfg_rules.ini".freeze

    def self.disable_tls
      LOGGER.debug("Invoked #{self.class}\##{__method__}")

      message = "Converting from unsecured LDAP authentication to SSSD. This is dangerous. Passwords are not encrypted"
      puts(message)
      LOGGER.warn(message)

      begin
        File.open(CFG_RULES_FILE, 'a') do |f|
          f << "option = ldap_auth_disable_tls_never_use_in_production\n"
        end
      rescue Errno::ENOENT => err
        LOGGER.fatal(err.message)
        raise ConfigureSssdRulesError, err.message
      end
    end
  end
end
