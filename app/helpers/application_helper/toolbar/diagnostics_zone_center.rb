class ApplicationHelper::Toolbar::DiagnosticsZoneCenter < ApplicationHelper::Toolbar::Basic
  button_group('support_reloading', [
    button(
      :reload_server_tree,
      'fa fa-repeat fa-lg',
      N_('Reload Current Display'),
      nil),
  ])
  button_group('ldap_domain_vmdb', [
    select(
      :support_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :zone_delete_server,
          'pficon pficon-delete fa-lg',
          t = N_('Delete Server #{@record.name} [#{@record.id}]'),
          t,
          :confirm => N_("Do you want to delete Server \#{@record.name} [\#{@record.id}]?")),
        button(
          :zone_role_start,
          'fa fa-play-circle-o fa-lg',
          N_('Start the #{@record.server_role.description} Role on Server #{@record.miq_server.name} [#{@record.miq_server.id}]'),
          N_('Start Role'),
          :confirm => N_("Start the \#{@record.server_role.description} Role on Server \#{@record.miq_server.name} [\#{@record.miq_server.id}]?")),
        button(
          :zone_role_suspend,
          'fa fa-pause-circle-o fa-lg',
          N_('Suspend the #{@record.server_role.description} Role on Server #{@record.miq_server.name} [#{@record.miq_server.id}]'),
          N_('Suspend Role'),
          :confirm => N_("Suspend the \#{@record.server_role.description} Role on Server \#{@record.miq_server.name} [\#{@record.miq_server.id}]?")),
        button(
          :zone_demote_server,
          'pficon pficon-delete fa-lg',
          N_('Demote Server #{@record.miq_server.name} [#{@record.miq_server.id}] to secondary for the #{@record.server_role.description} Role'),
          N_('Demote Server'),
          :confirm => N_("Do you want to demote this Server to secondary?  This will leave no primary Server for this Role.")),
        button(
          :zone_promote_server,
          'product product-migrate fa-lg',
          N_('Promote Server #{@record.miq_server.name} [#{@record.miq_server.id}] to primary for the #{@record.server_role.description} Role'),
          N_('Promote Server'),
          :confirm => N_("Do you want to promote this Server to primary?  This will replace any existing primary Server for this Role.")),
      ]
    ),
    select(
      :support_vmdb_choice,
      'fa fa-filter fa-lg',
      N_('Collect Logs'),
      N_('Collect'),
      :items => [
        button(
          :zone_collect_current_logs,
          'fa fa-filter fa-lg',
          N_('Collect the current logs from the selected #{ui_lookup(:table=>"zone")}'),
          N_('Collect current logs'),
          :klass => ApplicationHelper::Button::CollectLogs
        ),
        button(
          :zone_collect_logs,
          'fa fa-filter fa-lg',
          N_('Collect all logs from the selected #{ui_lookup(:table=>"zone")}'),
          N_('Collect all logs'),
          :klass => ApplicationHelper::Button::CollectLogs
        ),
      ]
    ),
    button(
      :zone_log_depot_edit,
      'pficon pficon-edit fa-lg',
      N_('Edit the Log Depot settings for the selected #{ui_lookup(:table=>"zone")}'),
      N_('Edit')),
  ])
end
