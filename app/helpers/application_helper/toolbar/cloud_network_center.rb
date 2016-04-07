class ApplicationHelper::Toolbar::CloudNetworkCenter < ApplicationHelper::Toolbar::Basic
  button_group('cloud_network_policy', [
    select(
      :cloud_network_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :items => [
        button(
          :cloud_network_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for this Floating IP'),
          N_('Edit Tags')),
      ]
    ),
  ])
end
