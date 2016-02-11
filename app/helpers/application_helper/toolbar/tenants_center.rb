class ApplicationHelper::Toolbar::TenantsCenter < ApplicationHelper::Toolbar::Basic
  button_group('rbac_tenant_vmdb', [
    select(
      :rbac_tenant_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :rbac_tenant_edit,
          'pficon pficon-edit fa-lg',
          N_('Select a single item to edit'),
          N_('Edit the selected item'),
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "1"),
        button(
          :rbac_tenant_delete,
          'pficon pficon-delete fa-lg',
          N_('Select one or more items to delete'),
          N_('Delete selected items'),
          :url_parms => "main_div",
          :confirm   => N_("Delete all selected items and all of their children?"),
          :enabled   => "false",
          :onwhen    => "1+"),
        button(
          :rbac_tenant_manage_quotas,
          'pficon pficon-edit fa-lg',
          N_('Select a single item to manage quotas'),
          N_('Manage Quotas for the Selected Item'),
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "1"),
      ]
    ),
  ])
  button_group('rbac_tenant_policy', [
    select(
      :rbac_group_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :items => [
        button(
          :rbac_tenant_tags_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit \'#{session[:customer_name]}\' Tags for the selected Tenant'),
          t,
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "1+"),
      ]
    ),
  ])
end
