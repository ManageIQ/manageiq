class ApplicationHelper::Toolbar::TenantCenter < ApplicationHelper::Toolbar::Basic
  button_group('rbac_tenant_vmdb', [
    select(:rbac_tenant_vmdb_choice, 'fa fa-cog fa-lg', N_('Configuration'), N_('Configuration'),
      :items     => [
        button(:rbac_tenant_add, 'pficon pficon-add-circle-o fa-lg', N_('Add child Tenant to this Tenant'), N_('Add child Tenant to this Tenant'),
          :url_parms => "?tenant_type=tenant"),
        button(:rbac_project_add, 'pficon pficon-add-circle-o fa-lg', N_('Add Project to this Tenant'), N_('Add Project to this Tenant'),
          :url_parms => "?tenant_type=project"),
        button(:rbac_tenant_edit, 'pficon pficon-edit fa-lg', N_('Edit this item'), N_('Edit this item')),
        button(:rbac_tenant_manage_quotas, 'pficon pficon-edit fa-lg', N_('Manage Quotas'), N_('Manage Quotas')),
        button(:rbac_tenant_delete, 'pficon pficon-delete fa-lg', N_('Delete this item'), N_('Delete this item'),
          :url_parms => "&refresh=y",
          :confirm   => N_("Are you sure you want to delete this item and all of it's children?")),
      ]
    ),
  ])
  button_group('rbac_tenant_policy', [
    select(:rbac_tenant_policy_choice, 'fa fa-shield fa-lg', N_('Policy'), N_('Policy'),
      :items     => [
        button(:rbac_tenant_tags_edit, 'pficon pficon-edit fa-lg', N_('Edit '#{session[:customer_name]}' Tags for this Tenant'), N_('Edit '#{session[:customer_name]}' Tags for this Tenant')),
      ]
    ),
  ])
end
