class ApplicationHelper::Toolbar::ContainerRouteCenter < ApplicationHelper::Toolbar::Basic
  button_group('container_route_policy', [
    select(
      :container_route_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :items => [
        button(
          :container_route_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for this Route'),
          N_('Edit Tags')),
      ]
    ),
  ])
end
