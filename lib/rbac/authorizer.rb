module Rbac
  class Authorizer
    def self.role_allows(*args)
      new.role_allows(*args)
    end

    def initialize

    end

    def role_allows(feature: nil, any: nil)
      userid  = User.current_userid
      role_id = User.current_user.miq_user_role.try(:id)
      if feature
        auth = any.present? ? User.current_user.role_allows_any?(:identifiers => [feature]) :
          User.current_user.role_allows?(:identifier => feature)
        $log.debug("Role Authorization #{auth ? "successful" : "failed"} for: userid [#{userid}], role id [#{role_id}], feature identifier [#{feature}]")
      else
        auth = false
        $log.debug("Role Authorization #{auth ? "successful" : "failed"} for: userid [#{userid}], role id [#{role_id}], no main tab or feature passed to role_allows")
      end
      auth
    end
  end
end
