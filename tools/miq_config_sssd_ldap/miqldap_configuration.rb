module MiqConfigSssdLdap
  class MiqLdapConfigurationArgumentError < StandardError; end

  class MiqLdapConfiguration
    NO_TLS_CERTS      = "TLS certificate were not provided and are required when mode is ldaps".freeze
    NO_BASE_DN_DOMAIN = "Unable to determine base DN domain name\nA Base DN domain name must be " <<
                        "specified on the command line when a Base DN is not already configured.".freeze

    NO_BIND_DN        = "Unable to determine bind DN\nA Bind DN must be specified on the command " <<
                        "line when a bind DN is not already configured.".freeze

    NO_BIND_PWD       = "Unable to determine bind pwd\nA Bind pwd must be specified on the command " <<
                        "line when a bind pwd is not already configured.".freeze

    attr_accessor :initial_settings

    def initialize(options = {})
      self.initial_settings = options[:action] == "config" ? options : current_authentication_settings.merge(options)
    end

    def retrieve_initial_settings
      check_for_tls_certs
      check_for_bind_dn
      check_for_bind_pwd
      derive_domain
    end

    private

    def check_for_domain
      if initial_settings[:domain].nil? && initial_settings[:basedn].nil?
        LOGGER.fatal(NO_BASE_DN_DOMAIN)
        raise MiqLdapConfigurationArgumentError, NO_BASE_DN_DOMAIN
      end
    end

    def check_for_bind_dn
      if initial_settings[:bind_dn].nil? && initial_settings[:mode] == "ldap"
        LOGGER.fatal(NO_BIND_DN)
        raise MiqLdapConfigurationArgumentError, NO_BIND_DN
      end
    end

    def check_for_bind_pwd
      if initial_settings[:bind_pwd].nil? && initial_settings[:mode] == "ldap"
        LOGGER.fatal(NO_BIND_PWD)
        raise MiqLdapConfigurationArgumentError, NO_BIND_PWD
      end
    end

    def check_for_tls_certs
      if initial_settings[:mode] == "ldaps" && initial_settings[:tls_cacert].nil?
        LOGGER.fatal(NO_TLS_CERTS)
        raise MiqLdapConfigurationArgumentError, NO_TLS_CERTS
      end
    end

    def current_authentication_settings
      LOGGER.debug("Invoked #{self.class}\##{__method__}")

      settings = Settings.authentication.to_hash
      LOGGER.debug("Current authentication settings: #{settings}")

      settings
    end

    def derive_domain
      check_for_domain

      # If the caller did not provide a base DN domain name derive it from the configured Base DN.
      if initial_settings[:domain].nil?
        initial_settings[:domain] = initial_settings[:basedn].downcase.split(",").collect do |p|
          p.split('dc=')[1]
        end.compact.join('.')
      end

      initial_settings
    end
  end
end
