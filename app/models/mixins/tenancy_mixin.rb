module TenancyMixin
  extend ActiveSupport::Concern

  module ClassMethods
    def scope_by_tenant?
      true
    end

    def accessible_tenant_ids(user_or_group, strategy)
      tenant = user_or_group.try(:current_tenant)
      return [] unless tenant

      tenant.accessible_tenant_ids(strategy)
    end
  end
end
