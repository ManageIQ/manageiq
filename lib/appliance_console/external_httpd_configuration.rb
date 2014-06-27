module ApplianceConsole
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

    RPM_COMMAND         = "/bin/rpm"
    SERVICE_COMMAND     = "/sbin/service"
    CHKCONFIG_COMMAND   = "/sbin/chkconfig"

    GETSEBOOL_COMMAND   = "/usr/sbin/getsebool"
    SETSEBOOL_COMMAND   = "/usr/sbin/setsebool"

    INTERCEPT_FORM      = "/dashboard/authenticate"

    LDAP_ATTRS          = {
      "mail"        => "REMOTE_USER_EMAIL",
      "givenname"   => "REMOTE_USER_FIRSTNAME",
      "sn"          => "REMOTE_USER_LASTNAME",
      "displayname" => "REMOTE_USER_FULLNAME"
    }

    #
    # IPA Configuration Methods
    #
    def ipa_client_configured?
      File.exist?(SSSD_CONFIG)
    end

    def ipa_client_configure(realm, domain, server, principal, password)
      say("Configuring the IPA Client ...")
      AwesomeSpawn.run!(IPA_INSTALL_COMMAND,
                        :params => {"-N"              => nil,
                                    "--force-join"    => nil,
                                    "--realm="        => realm,
                                    "--domain="       => domain,
                                    "--server="       => server,
                                    "--principal="    => principal,
                                    "--password="     => password,
                                    "--fixed-primary" => nil,
                                    "--unattended"    => nil})
    end

    def ipa_client_unconfigure
      say("Un-Configuring the IPA Client ...")
      AwesomeSpawn.run(IPA_INSTALL_COMMAND,
                       :params => {"--uninstall"  => nil,
                                   "--unattended" => nil})
    end

    #
    # HTTPD Configuration Methods
    #
    def httpd_mod_intercept_config
      config = "
LoadModule authnz_pam_module modules/mod_authnz_pam.so
LoadModule intercept_form_submit_module modules/mod_intercept_form_submit.so
LoadModule lookup_identity_module modules/mod_lookup_identity.so

<Location #{INTERCEPT_FORM}>
  InterceptFormPAMService #{PAM_MODULE}
  InterceptFormLogin      user_name
  InterceptFormPassword   user_password
  InterceptFormLoginSkip  admin
  InterceptFormClearRemoteUserForSkipped on
</Location>

<Location #{INTERCEPT_FORM}>
"
      LDAP_ATTRS.each { |ldap, http| config << "  LookupUserAttr #{ldap} #{http}\n" }
      config << "
  LookupUserGroups        REMOTE_USER_GROUPS \":\"
  LookupDbusTimeout       5000
</Location>
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
      if config.include?("[ifp]")
        config[/\[ifp\](\n.*)+user_attributes = (.*)/, 2] = user_attributes
      else
        config << "\n[ifp]
  allowed_uids = apache, root
  user_attributes = #{user_attributes}\n"
      end
    end

    #
    # RPM Utilities
    #
    def rpm_installed?(rpm_package)
      result = AwesomeSpawn.run!(RPM_COMMAND, :params => {"-qa" => rpm_package})
      if result.output.blank?
        say("#{rpm_package} RPM is not installed")
        return false
      end
      true
    end

    #
    # Validation Methods
    #
    def installation_valid?
      rpm_packages = %w(ipa-client sssd-dbus mod_intercept_form_submit mod_authnz_pam mod_lookup_identity)
      missing = rpm_packages.count { |package| !rpm_installed?(package) }
      if missing > 0
        say("\nAppliance Installation is not valid for enabling External Authentication\n")
        return false
      end
      true
    end

    def valid_environment?
      return false unless installation_valid?
      if ipa_client_configured?
        return false unless agree("\nIPA Client already configured on this Appliance, Un-Configure first? (Y/N): ")
        ipa_client_unconfigure
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
    def config_file_read(path)
      File.open(path, "r") { |f| f.read }
    end

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
end
