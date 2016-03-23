class ApplicationHelper::Toolbar::NetworkRouterCenter < ApplicationHelper::Toolbar::Basic
  button_group('network_router_policy', [
    select(
      :network_router_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :items => [
        button(
          :network_router_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for this Floating IP'),
          N_('Edit Tags')),
      ]
    ),
  ])
end
