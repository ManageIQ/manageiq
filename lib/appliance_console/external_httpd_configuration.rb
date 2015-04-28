module ApplianceConsole
  class ExternalHttpdAuthentication
    module ExternalHttpdConfiguration
      #
      # External Authentication Definitions
      #
      TEMPLATE_BASE_DIR   = "/var/www/miq/system/TEMPLATE/"

      IPA_COMMAND         = "/usr/bin/ipa"
      IPA_INSTALL_COMMAND = "/usr/sbin/ipa-client-install"
      IPA_GETKEYTAB       = "/usr/sbin/ipa-getkeytab"

      SSSD_CONFIG         = "/etc/sssd/sssd.conf"
      PAM_CONFIG          = "/etc/pam.d/httpd-auth"
      HTTP_KEYTAB         = "/etc/http.keytab"
      HTTP_REMOTE_USER    = "/etc/httpd/conf.d/cfme-remote-user.conf"
      HTTP_EXTERNAL_AUTH  = "/etc/httpd/conf.d/cfme-external-auth.conf"
      HTTP_EXTERNAL_AUTH_TEMPLATE = "#{HTTP_EXTERNAL_AUTH}.erb"

      GETSEBOOL_COMMAND   = "/usr/sbin/getsebool"
      SETSEBOOL_COMMAND   = "/usr/sbin/setsebool"
      GETENFORCE_COMMAND  = "/usr/sbin/getenforce"

      APACHE_USER         = "apache"

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
        say("Unconfiguring httpd ...")
        unconfigure_httpd_application

        say("Restarting httpd ...")
        LinuxAdmin::Service.new("httpd").restart
      end

      def configure_httpd_application
        cp_template(HTTP_EXTERNAL_AUTH_TEMPLATE, TEMPLATE_BASE_DIR)
        cp_template(HTTP_REMOTE_USER, TEMPLATE_BASE_DIR)
      end

      def unconfigure_httpd_application
        rm_file(HTTP_EXTERNAL_AUTH)
        rm_file(HTTP_REMOTE_USER)
      end

      #
      # SSSD File Methods
      #
      def configure_sssd_domain(config, domain)
        ldap_user_extra_attrs = LDAP_ATTRS.keys.join(", ")
        if config.include?("ldap_user_extra_attrs = ")
          pattern = "[domain/#{Regexp.escape(domain)}](\n.*)+ldap_user_extra_attrs = (.*)"
          config[/#{pattern}/, 2] = ldap_user_extra_attrs
        else
          pattern = "[domain/#{Regexp.escape(domain)}].*(\n)"
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
  allowed_uids = #{APACHE_USER}, root
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

      def cp_template(file, src_dir, dest_dir = "/")
        src_path  = path_join(src_dir, file)
        dest_path = path_join(dest_dir, file.gsub(".erb", ""))
        if src_path.to_s.include?(".erb")
          File.write(dest_path, ERB.new(File.read(src_path), nil, '-').result(binding))
        else
          FileUtils.cp src_path, dest_path
        end
      end

      def rm_file(file, dir = "/")
        path = path_join(dir, file)
        File.delete(path) if File.exist?(path)
      end

      def path_join(*args)
        path = Pathname.new(args.shift)
        args.each { |path_seg| path = path.join("./#{path_seg}") }
        path
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
