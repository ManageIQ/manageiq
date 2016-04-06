class ApplicationHelper::Toolbar::CloudTenantsCenter < ApplicationHelper::Toolbar::Basic
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
          N_('Edit tags for the selected items'),
          N_('Edit Tags'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1+"),
      ]
    ),
  ])
end
