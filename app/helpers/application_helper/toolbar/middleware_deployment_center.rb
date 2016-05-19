class ApplicationHelper::Toolbar::MiddlewareDeploymentCenter < ApplicationHelper::Toolbar::Basic
  button_group('middleware_deployment_policy', [
    select(
      :middleware_deployment_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :enabled => "false",
      :items   => [
        button(
          :middleware_deployment_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for this #{ui_lookup(:table=>"middleware_deployment")}'),
          N_('Edit Tags')),
      ]
    ),
  ])
end
