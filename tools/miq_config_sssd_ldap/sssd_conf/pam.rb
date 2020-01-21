require 'sssd_conf/common'

module MiqConfigSssdLdap
  class Pam < Common
    def initialize(initial_settings)
      super(%w[pam_app_services], initial_settings)
    end

    def pam_app_services
      "httpd-auth"
    end
  end
end
