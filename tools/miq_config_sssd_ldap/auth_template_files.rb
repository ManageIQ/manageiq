require 'fileutils'

module MiqConfigSssdLdap
  class AuthTemplateFilesError < StandardError; end

  class AuthTemplateFiles
    TEMPLATE_DIR     = "/opt/manageiq/manageiq-appliance/TEMPLATE".freeze
    ALT_TEMPLATE_DIR = "/opt/rh/cfme-appliance/TEMPLATE".freeze
    HTTPD_CONF_DIR   = "/etc/httpd/conf.d".freeze
    PAM_CONF_DIR     = "/etc/pam.d".freeze
    SSSD_CONF_DIR    = "/etc/sssd".freeze

    attr_reader :initial_settings, :template_dir

    def initialize(initial_settings)
      LOGGER.debug("Invoked #{self.class}\##{__method__}")

      @initial_settings = initial_settings

      @template_dir = Dir.exist?(TEMPLATE_DIR) ? TEMPLATE_DIR : ALT_TEMPLATE_DIR
    end
  end
end
