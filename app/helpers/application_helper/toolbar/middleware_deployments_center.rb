# noinspection RubyArgCount
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
  button_group('middleware_deployments_operations', [
    select(
      :middleware_deployment_deploy_choice,
      'fa fa-play-circle-o fa-lg',
      t = N_('Operations'),
      t,
      :enabled => false,
      :onwhen  => "1+",
      :items   => [
        button(
          :middleware_deployment_undeploy,
          'fa fa-eject fa-lg',
          N_('Undeploy these #{ui_lookup(:table=>"middleware_deployments")}'),
          N_('Undeploy'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1+",
          :confirm   => N_("Do you want to undeploy these deployments ?"))
      ]
    ),
  ])
end
