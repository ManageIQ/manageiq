class ApplicationHelper::Toolbar::TenantsCenter < ApplicationHelper::Toolbar::Basic
  button_group('rbac_tenant_vmdb', [
    {
      :buttonSelect => "rbac_tenant_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "rbac_tenant_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit the selected item"),
          :title        => N_("Select a single item to edit"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1",
        },
        {
          :button       => "rbac_tenant_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Delete selected items"),
          :title        => N_("Select one or more items to delete"),
          :url_parms    => "main_div",
          :confirm      => N_("Delete all selected items and all of their children?"),
          :enabled      => "false",
          :onwhen       => "1+",
        },
        {
          :button       => "rbac_tenant_manage_quotas",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Manage Quotas for the Selected Item"),
          :title        => N_("Select a single item to manage quotas"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1",
        },
      ]
    },
  ])
  button_group('rbac_tenant_policy', [
    {
      :buttonSelect => "rbac_group_policy_choice",
      :icon         => "fa fa-shield fa-lg",
      :title        => N_("Policy"),
      :text         => N_("Policy"),
      :items => [
        {
          :button       => "rbac_tenant_tags_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit '\#{session[:customer_name]}' Tags for the selected Tenant"),
          :title        => N_("Edit '\#{session[:customer_name]}' Tags for the selected Tenant"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1+",
        },
      ]
    },
  ])
end
