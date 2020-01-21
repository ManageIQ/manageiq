module Rbac
  class Authorizer
    include Vmdb::Logging

    def self.role_allows?(*args)
      new.role_allows?(*args)
    end

    def role_allows?(options = {})
      user    = options[:user]

      # 'identifier' comes from the back end (ex: User#role_allows?)
      # 'feature' comes from the front end (ex: ApplicationHelper#role_allows?)
      # As this API is a combination of the two, 'feature' is considered
      # an alias of 'identifier' for legacy purposes.
      identifier = options[:identifier] || options[:feature]

      # The 'identifiers' option comes from the former User#role_allows_any? API
      # It should be noted that there may be only ONE caller using 'identifiers'
      # in Menu::Section, so this option may be changed shortly.
      identifiers = options[:identifiers]

      any     = options[:any]

      tenant_identifier = MiqProductFeature.current_tenant_identifier(identifier)

      auth = if any.present?
               user_role_allows_any?(user, :identifiers => (identifiers || [identifier]))
             elsif tenant_identifier
               [identifier, tenant_identifier].any? { |i| user_role_allows?(user, :identifier => i) }
             else
               user_role_allows?(user, :identifier => identifier)
             end
      _log.debug("Auth #{auth ? "successful" : "failed"} for user '#{user.userid}', role '#{user.miq_user_role.try(:name)}', feature identifier '#{identifier}'")

      auth
    end

    private

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
      return false if user.miq_user_role.nil?
      user.miq_user_role.allows_any?(options)
    end
  end
end
