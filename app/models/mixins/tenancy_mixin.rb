module TenancyMixin
  extend ActiveSupport::Concern

  included do
    before_validation :set_tenant
  end

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

  def set_tenant
    # Priority
    #   Owning group
    #   Current user
    #   Parent EMS
    #   Root tenant
    self.tenant_id ||= if respond_to?(:miq_group) && miq_group.try(:tenant_id)
                         miq_group.tenant_id
                       elsif User.current_tenant.try(:id)
                         User.current_tenant.id
                       elsif respond_to?(:ext_management_system) && ext_management_system.try(:tenant_id)
                         ext_management_system.tenant_id
                       else
                         Tenant.root_tenant.try(:id)
                       end
  end
end
