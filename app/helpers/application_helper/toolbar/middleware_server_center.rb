# noinspection RubyArgCount
class ApplicationHelper::Toolbar::MiddlewareServerCenter < ApplicationHelper::Toolbar::Basic
  button_group('middleware_server_vmdb', [
    select(
      :middleware_server_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :middleware_server_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit this #{ui_lookup(:table=>"middleware_server")}'),
          t,
          :url => "/edit"),
        button(
          :middleware_server_delete,
          'pficon pficon-delete fa-lg',
          t = N_('Remove this #{ui_lookup(:table=>"middleware_server")} from the VMDB'),
          t,
          :url_parms => "&refresh=y",
          :confirm   => N_("Warning: This \#{ui_lookup(:table=>\"middleware_server\")} and ALL of its components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this \#{ui_lookup(:table=>\"middleware_server\")}?")),
      ]
    ),
  ])
  button_group('middleware_server_policy', [
    select(
      :middleware_server_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
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
          :confirm => N_("Do you want to suspend this server?")),
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
