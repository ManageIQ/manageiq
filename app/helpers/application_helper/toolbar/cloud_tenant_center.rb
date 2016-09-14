class ApplicationHelper::Toolbar::CloudTenantCenter < ApplicationHelper::Toolbar::Basic
  button_group('cloud_tenant_vmdb', [
    select(
      :cloud_tenant_vmdb_choice,
      'fa fa-shield fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :cloud_tenant_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit Cloud Tenant'),
          t),
        button(
          :cloud_tenant_delete,
          'pficon pficon-edit fa-lg',
          t = N_('Delete Cloud Tenant'),
          t),
      ]
    ),
  ])
  button_group('cloud_tenant_policy', [
    select(
      :cloud_tenant_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :items => [
        button(
          :cloud_tenant_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit tags for this Cloud Tenant'),
          N_('Edit Tags')),
      ]
    ),
  ])
end
