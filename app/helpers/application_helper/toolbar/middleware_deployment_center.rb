# noinspection RubyArgCount
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
          N_('Edit Tags for this Middleware Deployment'),
          N_('Edit Tags')),
      ]
    ),
  ])
  button_group('middleware_deployments_operations', [
    select(
      :middleware_deployment_deploy_choice,
      'fa fa-play-circle-o fa-lg',
      t = N_('Operations'),
      t,
      :items => [
        button(
          :middleware_deployment_redeploy,
          'pficon pficon-restart fa-lg',
          N_('Redeploy this Middleware Deployment'),
          N_('Redeploy'),
          :confirm => N_("Do you want to redeploy this deployment ?")),
        button(
          :middleware_deployment_undeploy,
          'fa fa-eject fa-lg',
          N_('Undeploy this Middleware Deployment'),
          N_('Undeploy'),
          :confirm => N_("Do you want to undeploy this deployment ?"))
      ]
    ),
  ])
end
