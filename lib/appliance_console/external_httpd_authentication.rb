require_relative "external_httpd_configuration"

module ApplianceConsole
  class ExternalHttpdAuthentication
    include ExternalHttpdConfiguration

    def initialize(host = nil, options = {})
      @ipaserver, @domain, @password = nil
      @host      = host
      @domain    = options[:domain] || domain_from_host(host)
      @ipaserver = options[:ipaserver]
      @principal = options[:principal] || "admin"
      @password  = options[:password]
      @timestamp = Time.now.strftime("%Y%m%d_%H%M%S")

      @ipaserver = fqdn(@ipaserver, @domain)
    end

    def ask_for_parameters
      say("\nIPA Server Parameters:\n\n")
      @ipaserver = ask_for_hostname("IPA Server Hostname", @ipaserver)
      @domain    = ask_for_domain("IPA Server Domain", @domain)
      @principal = just_ask("IPA Server Principal", @principal)
      @password  = ask_for_password("IPA Server Principal Password", @password)

      @ipaserver = fqdn(@ipaserver, @domain)
    end

    def show_parameters
      say("\nExternal Authentication (httpd) Configuration:\n")
      say("IPA Server Details:\n")
      say("  Hostname:       #{@ipaserver}\n")
      say("  Domain:         #{@domain}\n")
      say("  Realm:          #{realm}\n")
      say("  Naming Context: #{domain_naming_context}\n")
      say("  Principal:      #{@principal}\n")
    end

    def show_current_configuration
      return unless ipa_client_configured?
      config = config_file_read(SSSD_CONFIG)
      say("\nCurrent External Authentication (httpd) Configuration:\n")
      say("IPA Server Details:\n")
      say("  Hostname:       #{fetch_ipa_configuration("ipa_server", config)}\n")
      say("  Domain:         #{fetch_ipa_configuration("ipa_domain", config)}\n")
    end

    def ask_questions
      return false unless valid_environment?
      ask_for_parameters
      show_parameters
      return false unless agree("\nProceed? (Y/N): ")
      return false unless valid_parameters?(@ipaserver)
      true
    end

    def activate
      begin
        configure_ipa
        configure_pam
        configure_sssd
        configure_httpd_external_auth
        configure_httpd
        configure_selinux
      rescue => e
        say("Failed to Configure External Authentication - #{e}")
        return false
      end
      true
    end

    def post_activation
      say("\nRestarting sssd and httpd ...")
      %w(sssd httpd).each { |service| LinuxAdmin::Service.new(service).restart }

      say("Configuring sssd to start upon reboots ...")
      LinuxAdmin::Service.new("sssd").enable
    end

    private

    def domain_naming_context
      @domain.split(".").collect { |s| "dc=#{s}" }.join(",")
    end

    def domain_from_host(host)
      host.gsub(/^([^.]+\.)/, '') if host && host.include?('.')
    end

    def fqdn(host, domain)
      (host && domain && !host.include?(".")) ? "#{host}.#{domain}" : host
    end

    def realm
      @domain.upcase
    end

    def configure_ipa
      say("\nConfiguring IPA (may take a minute) ...")
      ipa_client_unconfigure if ipa_client_configured?
      ipa_client_configure(realm, @domain, @ipaserver, @principal, @password)
    end

    def configure_pam
      say("Configuring pam ...")
      config_file_write(PAM_CONFIGURATION, PAM_CONFIG, @timestamp)
    end

    def configure_sssd
      say("Configuring sssd ...")
      config = config_file_read(SSSD_CONFIG)
      configure_sssd_domain(config, @domain)
      configure_sssd_service(config)
      configure_sssd_ifp(config)
      config_file_write(config, SSSD_CONFIG, @timestamp)
    end

    def configure_httpd_external_auth
      say("Configuring httpd External Authentication ...")
      config_file_write(httpd_mod_intercept_config, HTTPD_EXTERNAL_AUTH, @timestamp)
    end

    def configure_httpd
      say("Configuring httpd ...")
      config = config_file_read(HTTPD_CONFIG)
      configure_httpd_application(config)
      config_file_write(config, HTTPD_CONFIG, @timestamp)
    end

    def configure_selinux
      say("Configuring SELinux ...")
      AwesomeSpawn.run!("#{SETSEBOOL_COMMAND} -P allow_httpd_mod_auth_pam on")
      result = AwesomeSpawn.run("#{GETSEBOOL_COMMAND} httpd_dbus_sssd")
      AwesomeSpawn.run!("#{SETSEBOOL_COMMAND} -P httpd_dbus_sssd on") if result.exit_status == 0
    end
  end
end
