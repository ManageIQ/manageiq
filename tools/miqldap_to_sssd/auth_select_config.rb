require 'awesome_spawn'
require 'miqldap_configuration'

module MiqLdapToSssd
  class AuthConfigError < StandardError; end

  class AuthConfig
    attr_reader :initial_settings

    def initialize(initial_settings)
      @initial_settings = initial_settings
    end

    def run_auth_config
      LOGGER.debug("Invoked #{self.class}\##{__method__}")

      ldapserver = "#{initial_settings[:mode]}://#{initial_settings[:ldaphost][0]}:#{initial_settings[:ldapport]}"
      params = {
        :ldapserver=        => ldapserver,
        :ldapbasedn=        => initial_settings[:basedn],
        :enablesssd         => nil,
        :enablesssdauth     => nil,
        :enablelocauthorize => nil,
        :enableldap         => nil,
        :enableldapauth     => nil,
        :disableldaptls     => nil,
        :enablerfc2307bis   => nil,
        :enablecachecreds   => nil,
        :update             => nil
      }

      result = AwesomeSpawn.run("authconfig", :params => params)
      LOGGER.debug("Ran command: #{result.command_line}")

      if result.failure?
        error_message = "authconfig failed with: #{result.error}"
        LOGGER.fatal(error_message)
        raise AuthConfigError, error_message
      end
    end
  end
end
