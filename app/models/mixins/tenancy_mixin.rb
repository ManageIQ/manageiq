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
      return [] if tenant.nil? || tenant.root?

      tenant.accessible_tenant_ids(strategy)
    end

    def tenant_id_clause(user_or_group)
      tenant_ids = accessible_tenant_ids(user_or_group, Rbac.accessible_tenant_ids_strategy(self))
      return if tenant_ids.empty?

      {table_name => {:tenant_id => tenant_ids}}
    end
  end

  def set_tenant
    # In priority order
    if respond_to?(:miq_group)
      self.miq_group ||= tenant_group || current_user_group || ems_tenant_group || root_tenant_group
    end
    self.tenant ||= owning_group_tenant ||
                    current_user_tenant ||
                    ems_tenant || root_tenant
  end

  private

  def owning_group_tenant
    miq_group.try(:tenant) if respond_to?(:miq_group)
  end

  def current_user_tenant
    User.current_tenant
  end

  def ems_tenant
    ext_management_system.try(:tenant) if respond_to?(:ext_management_system)
  end

  def root_tenant
    Tenant.root_tenant
  end

  def tenant_group
    tenant.try(:default_miq_group)
  end

  def current_user_group
    User.current_user.try(:current_group)
  end

  def ems_tenant_group
    ems_tenant.try(:default_miq_group)
  end

  def root_tenant_group
    root_tenant.try(:default_miq_group)
  end
end
