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
      return [] if tenant == Tenant.root_tenant

      tenant.accessible_tenant_ids(strategy)
    end
  end

  def set_tenant
    # In priority order
    self.tenant_id ||= owning_group_tenant ||
                       current_user_tenant ||
                       ems_tenant || root_tenant
  end

  private

  def owning_group_tenant
    miq_group.try(:tenant_id) if respond_to?(:miq_group)
  end

  def current_user_tenant
    User.current_tenant.try(:id)
  end

  def ems_tenant
    ext_management_system.try(:tenant_id) if respond_to?(:ext_management_system)
  end

  def root_tenant
    Tenant.root_tenant.try(:id)
  end
end
