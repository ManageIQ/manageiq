class ApplicationHelper::Toolbar::CloudSubnetCenter < ApplicationHelper::Toolbar::Basic
  button_group('cloud_subnet_policy', [
    select(
      :cloud_subnet_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :items => [
        button(
          :cloud_subnet_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for this Cloud Subnet'),
          N_('Edit Tags')),
      ]
    ),
  ])
end
