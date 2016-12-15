class ApplicationHelper::Toolbar::ContainerRoutesCenter < ApplicationHelper::Toolbar::Basic
  button_group('container_route_policy', [
    select(
      :container_route_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :enabled => false,
      :onwhen  => "1+",
      :items   => [
        button(
          :container_route_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for these Routes'),
          N_('Edit Tags'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1+"),
      ]
    ),
  ])
end
