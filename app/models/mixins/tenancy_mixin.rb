module TenancyMixin
  extend ActiveSupport::Concern

  included do
    before_validation :set_tenant
  end

  module ClassMethods
    include TenancyCommonMixin

    def scope_by_tenant?
      true
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
