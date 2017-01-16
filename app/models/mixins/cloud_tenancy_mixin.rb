module CloudTenancyMixin
  extend ActiveSupport::Concern

  module ClassMethods
    include TenancyCommonMixin

    def tenant_id_clause_format(tenant_ids)
      ["(tenants.id IN (?) AND ext_management_systems.tenant_mapping_enabled IS TRUE) OR ext_management_systems.tenant_mapping_enabled IS FALSE", tenant_ids]
    end

    def tenant_joins_clause(scope)
      scope.joins(:cloud_tenant => "source_tenant").joins(:ext_management_system)
    end
  end

  def tenant
    cloud_tenant
  end
end
