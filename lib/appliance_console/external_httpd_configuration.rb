module ApplianceConsole
  class ExternalHttpdAuthentication
    module ExternalHttpdConfiguration
      #
      # External Authentication Definitions
      #
      IPA_INSTALL_COMMAND = "/usr/sbin/ipa-client-install"

      PAM_MODULE          = "httpd-auth"
      PAM_CONFIG          = "/etc/pam.d/#{PAM_MODULE}"
      PAM_CONFIGURATION   = <<EOS
auth    required pam_sss.so
account required pam_sss.so
EOS
      SSSD_CONFIG         = "/etc/sssd/sssd.conf"

      EXTERNAL_AUTH_FILE  = "conf.d/cfme-external-auth"
      HTTPD_EXTERNAL_AUTH = "/etc/httpd/#{EXTERNAL_AUTH_FILE}"
      HTTPD_CONFIG        = "/etc/httpd/conf.d/cfme-https-application.conf"

      GETSEBOOL_COMMAND   = "/usr/sbin/getsebool"
      SETSEBOOL_COMMAND   = "/usr/sbin/setsebool"

      INTERCEPT_FORM      = "/dashboard/authenticate"
      INTERNAL_LOGIN      = "admin"

      TIMESTAMP_FORMAT    = "%Y%m%d_%H%M%S"

      LDAP_ATTRS          = {
        "mail"        => "REMOTE_USER_EMAIL",
        "givenname"   => "REMOTE_USER_FIRSTNAME",
        "sn"          => "REMOTE_USER_LASTNAME",
        "displayname" => "REMOTE_USER_FULLNAME"
      }

      #
      # IPA Configuration Methods
      #
      def ipa_client_configure(realm, domain, server, principal, password)
        say("Configuring the IPA Client ...")
        AwesomeSpawn.run!(IPA_INSTALL_COMMAND,
                          :params => [
                            "-N", :force_join, :fixed_primary, :unattended, {
                              :realm=     => realm,
                              :domain=    => domain,
                              :server=    => server,
                              :principal= => principal,
                              :password=  => password
                            }
                          ])
      end

      def ipa_client_unconfigure
        say("Un-Configuring the IPA Client ...")
        AwesomeSpawn.run(IPA_INSTALL_COMMAND, :params => [:uninstall, :unattended])
      end

      def unconfigure_httpd
        timestamp = Time.now.strftime(TIMESTAMP_FORMAT)

        say("Unconfiguring httpd ...")
        config = config_file_read(HTTPD_CONFIG)
        unconfigure_httpd_application(config)
        config_file_write(config, HTTPD_CONFIG, timestamp)

        say("Restarting httpd ...")
        LinuxAdmin::Service.new("httpd").restart
      end

      #
      # HTTPD Configuration Methods
      #
      def httpd_mod_intercept_config
        <<EOS

LoadModule authnz_pam_module modules/mod_authnz_pam.so
LoadModule intercept_form_submit_module modules/mod_intercept_form_submit.so
LoadModule lookup_identity_module modules/mod_lookup_identity.so
#{httpd_mod_intercept_config_ui}
#{httpd_mod_intercept_config_api}
EOS
      end

      def httpd_mod_intercept_config_ui
        <<EOS

<Location #{INTERCEPT_FORM}>
  InterceptFormPAMService #{PAM_MODULE}
  InterceptFormLogin      user_name
  InterceptFormPassword   user_password
  InterceptFormLoginSkip  #{INTERNAL_LOGIN}
  InterceptFormClearRemoteUserForSkipped on
</Location>

<Location #{INTERCEPT_FORM}>
#{httpd_mod_intercept_config_attrs}
</Location>
EOS
      end

      def httpd_mod_intercept_config_api
        <<EOS

<LocationMatch ^/api|^/vmdbws/wsdl|^/vmdbws/api>
  SetEnvIf Authorization '^Basic +YWRtaW46' let_admin_in
  SetEnvIf X-Auth-Token  '^.+$'             let_api_token_in

  AuthType Basic
  AuthName "External Authentication (httpd) for API"
  AuthBasicProvider PAM

  AuthPAMService #{PAM_MODULE}
  Require valid-user
  Order Allow,Deny
  Allow from env=let_admin_in
  Allow from env=let_api_token_in
  Satisfy Any

#{httpd_mod_intercept_config_attrs}
</LocationMatch>
EOS
      end

      def httpd_mod_intercept_config_attrs
        config = ""
        LDAP_ATTRS.each { |ldap, http| config << "  LookupUserAttr #{ldap} #{http}\n" }
        config << "
  LookupUserGroups        REMOTE_USER_GROUPS \":\"
  LookupDbusTimeout       5000
"
      end

      def httpd_external_auth_config
        config = "RequestHeader unset X_REMOTE_USER\n"
        attrs = %w(REMOTE_USER EXTERNAL_AUTH_ERROR) + LDAP_ATTRS.values + %w(REMOTE_USER_GROUPS)
        attrs.each { |attr| config << "RequestHeader set X_#{attr} %{#{attr}}e env=#{attr}\n" }
        config.chomp!
      end

      def configure_httpd_application(config)
        ext_auth_include = "Include #{EXTERNAL_AUTH_FILE}"
        unless config.include?(ext_auth_include)
          config[/(\n)<VirtualHost/, 1] = "\n#{ext_auth_include}\n\n"
        end

        if config.include?("set X_REMOTE_USER")
          config[/RequestHeader unset X_REMOTE_USER(\n.*)+env=REMOTE_USER_GROUPS/] = httpd_external_auth_config
        else
          config[/set X_FORWARDED_PROTO 'https'(\n)/, 1] = "\n\n#{httpd_external_auth_config}\n"
        end
      end

      def unconfigure_httpd_application(config)
        ext_auth_include = "Include #{EXTERNAL_AUTH_FILE}"
        if config.include?(ext_auth_include)
          config[/#{ext_auth_include}\n\n/] = ""
        end

        if config.include?("set X_REMOTE_USER")
          config[/RequestHeader unset X_REMOTE_USER(\n.*)+env=REMOTE_USER_GROUPS\n\n/] = ""
        end
      end

      #
      # SSSD File Methods
      #
      def configure_sssd_domain(config, domain)
        ldap_user_extra_attrs = LDAP_ATTRS.keys.join(", ")
        if config.include?("ldap_user_extra_attrs = ")
          pattern = "[domain/#{domain}](\n.*)+ldap_user_extra_attrs = (.*)"
          config[/#{pattern}/, 2] = ldap_user_extra_attrs
        else
          pattern = "[domain/#{domain}].*(\n)"
          config[/#{pattern}/, 1] = "\nldap_user_extra_attrs = #{ldap_user_extra_attrs}\n"
        end
      end

      def configure_sssd_service(config)
        services = config.match(/\[sssd\](\n.*)+services = (.*)/)[2]
        services = "#{services}, ifp" unless services.include?("ifp")
        config[/\[sssd\](\n.*)+services = (.*)/, 2] = services
      end

      def configure_sssd_ifp(config)
        user_attributes = LDAP_ATTRS.keys.collect { |k| "+#{k}" }.join(", ")
        ifp_config      = "
  allowed_uids = apache, root
  user_attributes = #{user_attributes}
"
        if config.include?("[ifp]")
          if config[/\[ifp\](\n.*)+user_attributes = (.*)/]
            config[/\[ifp\](\n.*)+user_attributes = (.*)/, 2] = user_attributes
          else
            config[/\[ifp\](\n)/, 1] = ifp_config
          end
        else
          config << "\n[ifp]#{ifp_config}\n"
        end
      end

      #
      # Validation Methods
      #
      def installation_valid?
        installed_rpm_packages = LinuxAdmin::Rpm.list_installed.keys
        rpm_packages = %w(ipa-client sssd-dbus mod_intercept_form_submit mod_authnz_pam mod_lookup_identity)

        missing = rpm_packages.count do |package|
          installed = installed_rpm_packages.include?(package)
          say("#{package} RPM is not installed") unless installed
          !installed
        end

        if missing > 0
          say("\nAppliance Installation is not valid for enabling External Authentication\n")
          return false
        end

        true
      end

      def valid_environment?
        return false unless installation_valid?
        if ipa_client_configured?
          show_current_configuration
          return false unless agree("\nIPA Client already configured on this Appliance, Un-Configure first? (Y/N): ")
          ipa_client_unconfigure
          unconfigure_httpd
          return false unless agree("\nProceed with External Authentication Configuration? (Y/N): ")
        end
        true
      end

      def valid_parameters?(ipaserver)
        host_reachable?(ipaserver, "IPA Server")
      end

      #
      # Config File I/O Methods
      #
      def config_file_write(config, path, timestamp)
        FileUtils.copy(path, "#{path}.#{timestamp}") if File.exist?(path)
        File.open(path, "w") { |f| f.write(config) }
      end

      #
      # Network validation
      #
      def host_reachable?(host, what = "Server")
        require 'net/ping'
        say("Checking connectivity to #{host} ... ")
        unless Net::Ping::External.new(host).ping
          say("Failed.\nCould not connect to #{host},")
          say("the #{what} must be reachable by name.")
          return false
        end
        say("Succeeded.")
        true
      end
    end

    def self.config_status
      fetch_ipa_configuration("ipa_server") || "not configured"
    end

    def self.ipa_client_configured?
      File.exist?(SSSD_CONFIG)
    end

    def self.config_file_read(path)
      File.read(path)
    end

    def self.fetch_ipa_configuration(what, config = nil)
      unless config
        return nil unless ipa_client_configured?
        config = config_file_read(SSSD_CONFIG)
      end
      pattern = "[domain/.*].*(\n.*)+#{Regexp.escape(what)} = (.*)"
      config[/#{pattern}/, 2]
    end

    delegate :ipa_client_configured?, :config_file_read, :fetch_ipa_configuration, :config_status, :to => self
  end
end
