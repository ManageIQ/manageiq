class ApplicationHelper::Toolbar::TenantCenter < ApplicationHelper::Toolbar::Basic
  button_group('rbac_tenant_vmdb', [
    {
      :buttonSelect => "rbac_tenant_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "rbac_tenant_add",
          :icon         => "pficon pficon-add-circle-o fa-lg",
          :text         => N_("Add child Tenant to this Tenant"),
          :title        => N_("Add child Tenant to this Tenant"),
          :url_parms    => "?tenant_type=tenant",
        },
        {
          :button       => "rbac_project_add",
          :icon         => "pficon pficon-add-circle-o fa-lg",
          :text         => N_("Add Project to this Tenant"),
          :title        => N_("Add Project to this Tenant"),
          :url_parms    => "?tenant_type=project",
        },
        {
          :button       => "rbac_tenant_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit this item"),
          :title        => N_("Edit this item"),
        },
        {
          :button       => "rbac_tenant_manage_quotas",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Manage Quotas"),
          :title        => N_("Manage Quotas"),
        },
        {
          :button       => "rbac_tenant_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Delete this item"),
          :title        => N_("Delete this item"),
          :url_parms    => "&refresh=y",
          :confirm      => N_("Are you sure you want to delete this item and all of it's children?"),
        },
      ]
    },
  ])
  button_group('rbac_tenant_policy', [
    {
      :buttonSelect => "rbac_tenant_policy_choice",
      :icon         => "fa fa-shield fa-lg",
      :title        => N_("Policy"),
      :text         => N_("Policy"),
      :items => [
        {
          :button       => "rbac_tenant_tags_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit '\#{session[:customer_name]}' Tags for this Tenant"),
          :title        => N_("Edit '\#{session[:customer_name]}' Tags for this Tenant"),
        },
      ]
    },
  ])
end
