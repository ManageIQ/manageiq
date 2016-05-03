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
          :url_parms => "?display=performance"),
        button(
          :middleware_server_timeline,
          'product product-timeline fa-lg',
          N_('Show Timelines for this Server'),
          N_('Timelines'),
          :enabled   => "false",
          :url       => "/show",
          :url_parms => "?display=timeline"),
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
          N_('Edit Tags for this #{ui_lookup(:table=>"middleware_server")}'),
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
          N_('Shut this #{ui_lookup(:table=>"middleware_server")} down'),
          N_('Shutdown Server'),
          :image   => "guest_shutdown",
          :confirm => N_("Do you want to shutdown this server?")),
        button(
          :middleware_server_restart,
          nil,
          N_('Restart this #{ui_lookup(:table=>"middleware_server")}'),
          N_('Restart Server'),
          :image   => "restart",
          :confirm => N_("Do you want to restart this server?")),
        separator,
        button(
          :middleware_server_stop,
          nil,
          N_('Stop this #{ui_lookup(:table=>"middleware_server")}'),
          N_('Stop Server'),
          :image   => "power_off",
          :confirm => N_("Do you want to stop this server?")),
        button(
          :middleware_server_suspend,
          nil,
          N_('Suspend this #{ui_lookup(:table=>"middleware_server")}'),
          N_('Suspend Server'),
          :image   => "suspend",
          :confirm => N_("Do you want to suspend this server?"),
          :form => {:id => :timeout,
                    :label => N_("Timeout"),
                    :default_value => 0}
        ),
        button(
          :middleware_server_resume,
          nil,
          N_('Resume this #{ui_lookup(:table=>"middleware_server")}'),
          N_('Resume Server'),
          :image   => "placeholder",
          :confirm => N_("Do you want to resume this server?")),
        button(
          :middleware_server_reload,
          nil,
          N_('Reload this #{ui_lookup(:table=>"middleware_server")}'),
          N_('Reload Server'),
          :image   => "guest_restart",
          :confirm => N_("Do you want to trigger a reload of this server?")),
        separator,
        button(
          :middleware_server_jdr,
          nil,
          N_('Generate a JDR report for this #{ui_lookup(:table=>"middleware_server")}'),
          N_('Generate JDR report'),
          :image   => "export",
          :confirm => N_("Do you want to trigger the generation of a JDR report?")),
      ]
    ),
  ])
end
