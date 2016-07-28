module Rbac
  class Authorizer
    include Vmdb::Logging

    def self.role_allows(*args)
      new.role_allows(*args)
    end

    def initialize

    end

    def role_allows(user:, feature:, any: nil)
      auth = any.present? ? user.role_allows_any?(:identifiers => [feature]) : user.role_allows?(:identifier => feature)
      _log.debug("Auth #{auth ? "successful" : "failed"} for user '#{user.userid}', role '#{user.miq_user_role.try(:name)}', feature identifier '#{feature}'")

      auth
    end
  end
end
