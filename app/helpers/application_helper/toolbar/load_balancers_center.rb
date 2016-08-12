class ApplicationHelper::Toolbar::LoadBalancersCenter < ApplicationHelper::Toolbar::Basic
  button_group('load_balancer_policy', [
    select(
      :load_balancer_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :enabled => false,
      :onwhen  => "1+",
      :items   => [
        button(
          :load_balancer_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for the selected Load Balancers'),
          N_('Edit Tags'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1+"),
      ]
    ),
  ])
end
