class ApplicationHelper::Toolbar::MiddlewareDatasourceCenter < ApplicationHelper::Toolbar::Basic
  button_group('middleware_datasource_monitoring', [
    select(
      :middleware_datasource_monitoring_choice,
      'product product-monitoring fa-lg',
      t = N_('Monitoring'),
      t,
      :items => [
        button(
          :middleware_datasource_perf,
          'product product-monitoring fa-lg',
          N_('Show Capacity & Utilization data for this Datasource'),
          N_('Utilization'),
          :url       => "/show",
          :url_parms => "?display=performance")
      ]
    ),
  ])
  button_group('middleware_datasource_policy', [
    select(
      :middleware_datasource_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :enabled => "false",
      :items   => [
        button(
          :middleware_datasource_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for this Middleware Datasource'),
          N_('Edit Tags')),
      ]
    ),
  ])
end
