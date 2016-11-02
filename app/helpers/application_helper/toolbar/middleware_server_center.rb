# noinspection RubyArgCount
class ApplicationHelper::Toolbar::MiddlewareServerCenter < ApplicationHelper::Toolbar::Basic
  button_group('middleware_server_monitoring', [
    select(
      :middleware_server_monitoring_choice,
      'product product-monitoring fa-lg',
      t = N_('Monitoring'),
      t,
      :items => [
        button(
          :middleware_server_perf,
          'product product-monitoring fa-lg',
          N_('Show Capacity & Utilization data for this Server'),
          N_('Utilization'),
          :url       => "/show",
          :url_parms => "?display=performance")
      ]
    ),
  ])
  button_group('middleware_server_policy', [
    select(
      :middleware_server_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :enabled => "false",
      :items => [
        button(
          :middleware_server_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for this Middleware Server'),
          N_('Edit Tags')),
      ]
    ),
  ])
  button_group('middleware_server_operations', [
    select(
      :middleware_server_power_choice,
      'fa fa-power-off fa-lg',
      t = N_('Power'),
      t,
      :items => [
        button(
          :middleware_server_shutdown,
          nil,
          N_('Gracefully shut this server down'),
          N_('Gracefully shutdown Server'),
          :image => "guest_shutdown",
          :data  => {'toggle'        => 'modal',
                     'target'        => '#modal_param_div',
                     'function'      => 'sendDataWithRx',
                     'function-data' => '{"type": "mwServerOps", "operation": "shutdown", "timeout": 0}'},
          :klass => ApplicationHelper::Button::MiddlewareAction),
        button(
          :middleware_server_restart,
          nil,
          N_('Restart this server'),
          N_('Restart Server'),
          :image   => 'restart',
          :confirm => N_("Do you want to restart this server?"),
          :klass   => ApplicationHelper::Button::MiddlewareAction),
        separator,
        button(
          :middleware_server_stop,
          nil,
          N_('Stop this Middleware Server'),
          N_('Stop Server'),
          :image   => "power_off",
          :confirm => N_("Do you want to stop this server?"),
          :klass   => ApplicationHelper::Button::MiddlewareAction),
        button(
          :middleware_server_suspend,
          nil,
          N_('Suspend this server'),
          N_('Suspend Server'),
          :image => "suspend",
          :data  => {'toggle'        => 'modal',
                     'target'        => '#modal_param_div',
                     'function'      => 'sendDataWithRx',
                     'function-data' => '{"type": "mwServerOps", "operation": "suspend", "timeout": 10}'},
          :klass => ApplicationHelper::Button::MiddlewareAction),
        button(
          :middleware_server_resume,
          nil,
          N_('Resume this server'),
          N_('Resume Server'),
          :image   => "resume",
          :confirm => N_("Do you want to resume this server?"),
          :klass   => ApplicationHelper::Button::MiddlewareAction),
        button(
          :middleware_server_reload,
          'pficon pficon-restart fa-lg',
          N_('Reload this server'),
          N_('Reload Server'),
          :confirm => N_("Do you want to trigger a reload of this server?"),
          :klass   => ApplicationHelper::Button::MiddlewareAction)
      ]
    ),
  ])
  button_group('middleware_server_deployments', [
    select(
      :middleware_server_deployments_choice,
      'pficon pficon-save fa-lg',
      t = N_('Deployments'),
      t,
      :items => [
        button(
          :middleware_deployment_add,
          'pficon pficon-add-circle-o fa-lg',
          N_('Add a new Middleware Deployment'),
          N_('Add Deployment'),
          :data => {'toggle'        => 'modal',
                    'target'        => '#modal_d_div',
                    'function'      => 'miqCallAngular',
                    'function-data' => '{"name": "showDeployListener", "args": []}'},
          :klass => ApplicationHelper::Button::MiddlewareInstanceAdd)
      ]
    ),
  ])
  button_group('middleware_server_jdbc_drivers', [
    select(
      :middleware_server_jdbc_drivers_choice,
      'fa fa-plug fa-lg',
      t = N_('JDBC Drivers'),
      t,
      :items => [
        button(
          :middleware_jdbc_driver_add,
          'fa fa-plug fa-lg',
          N_('Add a new Middleware JDBC Driver'),
          N_('Add JDBC Driver'),
          :data => {'toggle'        => 'modal',
                    'target'        => '#modal_jdbc_div',
                    'function'      => 'miqCallAngular',
                    'function-data' => '{"name": "showJdbcDriverListener", "args": []}'},
          :klass => ApplicationHelper::Button::MiddlewareInstanceAdd)
      ]
    ),
  ])
  button_group('middleware_server_datasources', [
    select(
      :middleware_server_datasources_choice,
      'fa fa-database fa-lg',
      t = N_('Datasources'),
      t,
      :items => [
        button(
          :middleware_datasource_add,
          'fa fa-database fa-lg',
          N_('Add a new Middleware Datasource'),
          N_('Add Datasource'),
          :data => {'toggle'        => 'modal',
                    'target'        => '#modal_ds_div',
                    'function'      => 'miqCallAngular',
                    'function-data' => '{"name": "showDatasourceListener", "args": []}'},
          :klass => ApplicationHelper::Button::MiddlewareInstanceAdd)
      ]
    ),
  ])
end
