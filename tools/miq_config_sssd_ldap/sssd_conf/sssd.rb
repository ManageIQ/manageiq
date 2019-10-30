require 'sssd_conf/common'

module MiqConfigSssdLdap
  class Sssd < Common
    def initialize(initial_settings)
      super(%w[config_file_version
               default_domain_suffix
               domains
               sbus_timeout
               services], initial_settings)
    end

    def config_file_version
      "2"
    end

    def default_domain_suffix
      initial_settings[:domain]
    end

    def domains
      initial_settings[:domain]
    end

    def sbus_timeout
      "30"
    end

    def services
      "nss, pam, ifp"
    end
  end
end
