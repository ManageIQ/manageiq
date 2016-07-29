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

    def user_role_allows?(user, options = {})
      return false if user.miq_user_role.nil?
      return true if user.miq_user_role.allows?(options)

      ident = options[:identifier]
      parent = MiqProductFeature.feature_parent(ident)
      return false if parent.nil?

      if MiqProductFeature.feature_hidden(ident)
        # return true for common features that are hidden and are under hidden parent
        # return true if any visible siblings are entitled
        if MiqProductFeature.feature_hidden(parent)
          true
        else
          user.miq_user_role.allows_any?(:identifiers => MiqProductFeature.feature_children(parent))
        end
      end
    end

    def user_role_allows_any?(user, options = {})
      binding.pry if ENV["LOLZ"]
      return false if user.miq_user_role.nil?
      user.miq_user_role.allows_any?(options)
    end
  end
end
