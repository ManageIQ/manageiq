class AssignTenantDefaultGroup < ActiveRecord::Migration
  class Tenant < ActiveRecord::Base
    def add_default_miq_group
      tenant_group = ::AssignTenantDefaultGroup::MiqGroup.create_tenant_group(self)
      update_attributes!(:default_miq_group_id => tenant_group.id)
    end

    def root?
      ancestry.nil?
    end
  end

  class MiqUserRole < ActiveRecord::Base
    DEFAULT_TENANT_ROLE_NAME = "EvmRole-tenant_administrator"

    # if there is no role, that is ok
    # MiqGroup.seed will populate

    def self.default_tenant_role
      @default_role ||= find_by(:name => DEFAULT_TENANT_ROLE_NAME)
    end
  end

  class MiqGroup < ActiveRecord::Base
    TENANT_GROUP = "tenant"

    def self.create_tenant_group(tenant)
      role = ::AssignTenantDefaultGroup::MiqUserRole.default_tenant_role
      create_with(
        :description      => "Tenant #{tenant.name} #{tenant.id} access",
        :group_type       => TENANT_GROUP,
        :sequence         => 1,
        :guid             => MiqUUID.new_guid,
        :miq_user_role_id => role.try(:id)
      ).find_or_create_by!(:tenant_id => tenant.id)
    end
  end

  def up
    say_with_time "adding default tenant groups" do
      Tenant.where(:default_miq_group_id => nil).each(&:add_default_miq_group)
    end
  end
end
