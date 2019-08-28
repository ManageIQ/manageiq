require 'sssd_conf/common'

module MiqConfigSssdLdap
  class Ifp < Common
    def initialize(initial_settings)
      super(%w[allowed_uids user_attributes], initial_settings)
    end

    def allowed_uids
      "apache, root"
    end

    def user_attributes
      USER_ATTRS.map { |attr| "+#{attr}" }.join(", ")
    end
  end
end
