module TenancyCommonMixin
  def accessible_tenant_ids(user_or_group, strategy)
    tenant = user_or_group.try(:current_tenant)
    return [] if tenant.nil? || tenant.root?

    tenant.accessible_tenant_ids(strategy)
  end

  def tenant_id_clause(user_or_group)
    tenant_ids = accessible_tenant_ids(user_or_group, Rbac.accessible_tenant_ids_strategy(self))
    return if tenant_ids.empty?

    tenant_id_clause_format(tenant_ids)
  end

  def tenant_id_clause_format(tenant_ids)
    {table_name => {:tenant_id => tenant_ids}}
  end

  def additional_tenants_clause(tenant)
    where(table_name => {:tenants => {:id => tenant.id}})
  end
end
