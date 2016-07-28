module Rbac
  class Authorizer
    include Vmdb::Logging

    def self.role_allows(*args)
      new.role_allows(*args)
    end

    def initialize

    end

    def role_allows(user:, feature:, any: nil)
      userid  = user.id
      role_id = user.miq_user_role.try(:id)
      auth = any.present? ? user.role_allows_any?(:identifiers => [feature]) : user.role_allows?(:identifier => feature)
      _log.info("Auth #{auth ? "successful" : "failed"} for: userid [#{userid}], role id [#{role_id}], feature identifier [#{feature}]")

      auth
    end
  end
end
