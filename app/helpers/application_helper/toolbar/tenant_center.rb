class ApplicationHelper::Toolbar::TenantCenter < ApplicationHelper::Toolbar::Basic
  button_group('rbac_tenant_vmdb', [
    select(
      :rbac_tenant_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :rbac_tenant_add,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Add child Tenant to this Tenant'),
          t,
          :klass     => ApplicationHelper::Button::TenantAdd,
          :options   => {:feature => 'rbac_tenant_add'},
          :url_parms => "?tenant_type=tenant"),
        button(
          :rbac_project_add,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Add Project to this Tenant'),
          t,
          :klass     => ApplicationHelper::Button::TenantAdd,
          :options   => {:feature => 'rbac_project_add'},
          :url_parms => "?tenant_type=project"),
        button(
          :rbac_tenant_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit this item'),
          t),
        button(
          :rbac_tenant_manage_quotas,
          'pficon pficon-edit fa-lg',
          t = N_('Manage Quotas'),
          t),
        button(
          :rbac_tenant_delete,
          'pficon pficon-delete fa-lg',
          t = N_('Delete this item'),
          t,
          :url_parms => "&refresh=y",
          :confirm   => N_("Are you sure you want to delete this item and all of it's children?")),
      ]
    ),
  ])
  button_group('rbac_tenant_policy', [
    select(
      :rbac_tenant_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :items => [
        button(
          :rbac_tenant_tags_edit,
          'pficon pficon-edit fa-lg',
          t = proc do
            _('Edit \'%{customer_name}\' Tags for this Tenant') % {:customer_name => @view_context.session[:customer_name]}
          end,
          t),
      ]
    ),
  ])
end
