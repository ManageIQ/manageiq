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
  button_group('middleware_deployment_operations', [
    select(
      :middleware_deployment_deploy_choice,
      'fa fa-play-circle-o fa-lg',
      t = N_('Operations'),
      t,
      :items => [
        button(
          :middleware_deployment_restart,
          'pficon pficon-restart fa-lg',
          N_('Restart this Middleware Deployment'),
          N_('Restart'),
          :confirm => N_("Do you want to restart this deployment ?"),
          :klass   => ApplicationHelper::Button::MiddlewareInstanceAdd),
        button(
          :middleware_deployment_disable,
          'fa fa-stop-circle-o fa-lg',
          N_('Disable this Middleware Deployment'),
          N_('Disable'),
          :confirm => N_("Do you want to disable this deployment ?"),
          :klass   => ApplicationHelper::Button::MiddlewareInstanceAdd),
        button(
          :middleware_deployment_enable,
          'fa fa-play-circle-o fa-lg',
          N_('Enable this Middleware Deployment'),
          N_('Enable'),
          :confirm => N_("Do you want to enable this deployment ?"),
          :klass   => ApplicationHelper::Button::MiddlewareInstanceAdd),
        button(
          :middleware_deployment_undeploy,
          'fa fa-eject fa-lg',
          N_('Undeploy this Middleware Deployment'),
          N_('Undeploy'),
          :confirm => N_("Do you want to undeploy this deployment ?"),
          :klass   => ApplicationHelper::Button::MiddlewareInstanceAdd)
      ]
    ),
  ])
end
