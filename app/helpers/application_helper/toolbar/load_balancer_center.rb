class ApplicationHelper::Toolbar::LoadBalancerCenter < ApplicationHelper::Toolbar::Basic
  button_group('load_balancer_policy', [
    select(
      :load_balancer_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :items => [
        button(
          :load_balancer_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for this Load Balancer'),
          N_('Edit Tags')),
      ]
    ),
  ])
end
