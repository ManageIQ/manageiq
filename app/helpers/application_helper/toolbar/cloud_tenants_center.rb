class ApplicationHelper::Toolbar::CloudTenantsCenter < ApplicationHelper::Toolbar::Basic
  button_group('cloud_tenant_vmdb', [
    select(
      :cloud_tenant_vmdb_choice,
      'fa fa-shield fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :cloud_tenant_new,
          'pficon pficon-edit fa-lg',
          t = N_('Create Cloud Tenant'),
          t),
        button(
          :cloud_tenant_edit,
          'pficon pficon-edit fa-lg',
          N_('Select a single Cloud Tenant to edit'),
          N_('Edit Selected Cloud Tenant'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1"),
        button(
          :cloud_tenant_delete,
          'pficon pficon-delete fa-lg',
          N_('Delete selected Cloud Tenants'),
          N_('Delete Cloud Tenants'),
          :url_parms => "main_div",
          :confirm   => N_("Warning: The selected Cloud Tenants will be permanently deleted!"),
          :enabled   => false,
          :onwhen    => "1+"),
      ]
    ),
  ])
  button_group('cloud_tenant_policy', [
    select(
      :cloud_tenant_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :enabled => false,
      :onwhen  => "1+",
      :items => [
        button(
          :cloud_tenant_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit tags for the selected items'),
          N_('Edit Tags'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1+"),
      ]
    ),
  ])
end
