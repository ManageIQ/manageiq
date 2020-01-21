module CloudTenancyMixin
  extend ActiveSupport::Concern

  module ClassMethods
    include TenancyCommonMixin

    def scope_by_cloud_tenant?
      true
    end

    def tenant_id_clause_format(tenant_ids)
      ["(tenants.id IN (?) AND ext_management_systems.tenant_mapping_enabled IS TRUE) OR ext_management_systems.tenant_mapping_enabled IS FALSE OR ext_management_systems.tenant_mapping_enabled IS NULL", tenant_ids]
    end

    def tenant_joins_clause(scope)
      scope.includes(:cloud_tenant => "source_tenant", :ext_management_system => {})
           .references(:cloud_tenants, :tenants, :ext_management_systems) # needed for the where to work
    end
  end
end
