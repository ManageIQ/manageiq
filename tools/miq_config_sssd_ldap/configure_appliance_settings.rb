require 'fileutils'

module MiqConfigSssdLdap
  class ConfigureApplianceSettingsError < StandardError; end

  class ConfigureApplianceSettings
    attr_reader :initial_settings

    def initialize(initial_settings)
      @initial_settings = initial_settings
    end

    def configure
      LOGGER.debug("Invoked #{self.class}\##{__method__} initial_settings  #{initial_settings} ")

      ldap_role = initial_settings[:ldap_role].nil? ? Settings.authentication.ldap_role : initial_settings[:ldap_role]

      new_settings = {
        :authentication => {:mode       => "httpd",
                            :httpd_role => ldap_role,
                            :ldap_role  => false}
      }

      log_configuration("Initial", Settings.authentication)
      MiqServer.my_server.add_settings_for_resource(new_settings)
      log_configuration("Updated", Settings.authentication)
    end

    private

    def log_configuration(current_state, auth_config)
      LOGGER.debug("#{current_state}       mode: #{auth_config[:mode]}")
      LOGGER.debug("#{current_state} httpd_role: #{auth_config[:httpd_role]}")
      LOGGER.debug("#{current_state}  ldap_role: #{auth_config[:ldap_role]}")
    end
  end
end
