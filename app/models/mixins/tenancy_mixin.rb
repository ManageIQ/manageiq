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
    #   Current user
    #   Owning group
    #   Parent EMS
    #   Root tenant
    self.tenant_id = if User.current_user
                  User.current_user.miq_group.tenant_id
                elsif respond_to?(:miq_group) && miq_group
                  miq_group.tenant_id
                elsif respond_to?(:ext_management_system) && ext_management_system
                  ext_management_system.tenant_id
                else
                  Tenant.root_tenant.id
                end
  end
end
