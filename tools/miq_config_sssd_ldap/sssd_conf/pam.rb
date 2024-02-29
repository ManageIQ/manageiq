require 'sssd_conf/common'

module MiqConfigSssdLdap
  class Pam < Common
    def initialize(initial_settings)
      super(%w[pam_app_services pam_initgroups_scheme], initial_settings)
    end

    def pam_app_services
      "httpd-auth"
    end

    def pam_initgroups_scheme
      "always"
    end
  end
end
