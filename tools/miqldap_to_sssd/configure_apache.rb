require 'fileutils'

module MiqLdapToSssd
  class ConfigureApacheError < StandardError; end

  class ConfigureApache
    TEMPLATE_DIR     = "/var/www/miq/system/TEMPLATE".freeze
    ALT_TEMPLATE_DIR = "/opt/rh/cfme-appliance/TEMPLATE".freeze
    HTTPD_CONF_DIR   = "/etc/httpd/conf.d".freeze
    PAM_CONF_DIR     = "/etc/pam.d".freeze

    attr_reader :initial_settings, :template_dir

    def initialize(initial_settings)
      @initial_settings = initial_settings
      @template_dir = Dir.exist?(TEMPLATE_DIR) ? TEMPLATE_DIR : ALT_TEMPLATE_DIR
    end

    def configure
      LOGGER.debug("Invoked #{self.class}\##{__method__} template_dir #{template_dir}")
      create_files
      update_realm
    end

    private

    def create_files
      LOGGER.debug("Invoked #{self.class}\##{__method__}")

      begin
        FileUtils.cp("#{template_dir}#{PAM_CONF_DIR}/httpd-auth", "#{PAM_CONF_DIR}/httpd-auth")
        FileUtils.cp("#{template_dir}#{HTTPD_CONF_DIR}/manageiq-remote-user.conf", HTTPD_CONF_DIR)
        FileUtils.cp("#{template_dir}#{HTTPD_CONF_DIR}/manageiq-external-auth.conf.erb",
                     "#{HTTPD_CONF_DIR}/manageiq-external-auth.conf")
      rescue Errno::ENOENT => err
        LOGGER.fatal(err.message)
        raise ConfigureApacheError, err.message
      end
    end

    def update_realm
      LOGGER.debug("Invoked #{self.class}\##{__method__}")

      begin
        miq_ext_auth = File.read("#{HTTPD_CONF_DIR}/manageiq-external-auth.conf")
        miq_ext_auth[/(\s*)KrbAuthRealms(\s*)(.*)/, 3] = initial_settings[:domain] if miq_ext_auth.include?("KrbAuthRealms")
        File.write("#{HTTPD_CONF_DIR}/manageiq-external-auth.conf", miq_ext_auth)
      rescue Errno::ENOENT, IndexError => err
        LOGGER.fatal(err.message)
        raise ConfigureApacheError, err.message
      end
    end
  end
end
