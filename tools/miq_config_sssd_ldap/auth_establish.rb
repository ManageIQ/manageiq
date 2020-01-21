require 'awesome_spawn'
require 'miqldap_configuration'

module MiqConfigSssdLdap
  class AuthEstablishError < StandardError; end

  class AuthEstablish
    attr_reader :initial_settings

    def initialize(initial_settings)
      @initial_settings = initial_settings
    end

    def run_auth_establish
      authselect_found? ? run_auth_select : run_auth_config
    end

    private

    def authselect_found?
      ENV['PATH'].split(':').any? { |dir| File.exist?("#{dir}/authselect") }
    end

    def run_auth_select
      LOGGER.debug("Invoked #{self.class}\##{__method__}")

      result = AwesomeSpawn.run("authselect select sssd --force")
      LOGGER.debug("Ran command: #{result.command_line}")

      if result.failure?
        error_message = "authselect failed with: #{result.error}"
        LOGGER.fatal(error_message)
        raise AuthEstablishError, error_message
      end
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
        raise AuthEstablishError, error_message
      end
    end
  end
end
