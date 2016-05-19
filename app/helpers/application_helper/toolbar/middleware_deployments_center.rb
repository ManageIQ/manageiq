class ApplicationHelper::Toolbar::MiddlewareDeploymentsCenter < ApplicationHelper::Toolbar::Basic
  button_group('middleware_deployments_policy', [
    select(
      :middleware_deployment_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :enabled => false,
      :onwhen  => "1+",
      :items   => [
        button(
          :middleware_deployment_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for these #{ui_lookup(:table=>"middleware_deployments")}'),
          N_('Edit Tags'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1+"),
      ]
    ),
  ])
end
