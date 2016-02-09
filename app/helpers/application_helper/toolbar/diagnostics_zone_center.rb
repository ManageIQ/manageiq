class ApplicationHelper::Toolbar::DiagnosticsZoneCenter < ApplicationHelper::Toolbar::Basic
  button_group('support_reloading', [
    {
      :button       => "reload_server_tree",
      :icon         => "fa fa-repeat fa-lg",
      :title        => N_("Reload Current Display"),
    },
  ])
  button_group('ldap_domain_vmdb', [
    {
      :buttonSelect => "support_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "zone_delete_server",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Delete Server \#{@record.name} [\#{@record.id}]"),
          :title        => N_("Delete Server \#{@record.name} [\#{@record.id}]"),
          :confirm      => N_("Do you want to delete Server \#{@record.name} [\#{@record.id}]?"),
        },
        {
          :button       => "zone_role_start",
          :icon         => "fa fa-play-circle-o fa-lg",
          :text         => N_("Start Role"),
          :title        => N_("Start the \#{@record.server_role.description} Role on Server \#{@record.miq_server.name} [\#{@record.miq_server.id}]"),
          :confirm      => N_("Start the \#{@record.server_role.description} Role on Server \#{@record.miq_server.name} [\#{@record.miq_server.id}]?"),
        },
        {
          :button       => "zone_role_suspend",
          :icon         => "fa fa-pause-circle-o fa-lg",
          :text         => N_("Suspend Role"),
          :title        => N_("Suspend the \#{@record.server_role.description} Role on Server \#{@record.miq_server.name} [\#{@record.miq_server.id}]"),
          :confirm      => N_("Suspend the \#{@record.server_role.description} Role on Server \#{@record.miq_server.name} [\#{@record.miq_server.id}]?"),
        },
        {
          :button       => "zone_demote_server",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Demote Server"),
          :title        => N_("Demote Server \#{@record.miq_server.name} [\#{@record.miq_server.id}] to secondary for the \#{@record.server_role.description} Role"),
          :confirm      => N_("Do you want to demote this Server to secondary?  This will leave no primary Server for this Role."),
        },
        {
          :button       => "zone_promote_server",
          :icon         => "product product-migrate fa-lg",
          :text         => N_("Promote Server"),
          :title        => N_("Promote Server \#{@record.miq_server.name} [\#{@record.miq_server.id}] to primary for the \#{@record.server_role.description} Role"),
          :confirm      => N_("Do you want to promote this Server to primary?  This will replace any existing primary Server for this Role."),
        },
      ]
    },
    {
      :buttonSelect => "support_vmdb_choice",
      :icon         => "fa fa-filter fa-lg",
      :title        => N_("Collect Logs"),
      :text         => N_("Collect"),
      :items => [
        {
          :button       => "zone_collect_current_logs",
          :icon         => "fa fa-filter fa-lg",
          :text         => N_("Collect current logs"),
          :title        => N_("Collect the current logs from the selected \#{ui_lookup(:table=>\"zone\")}"),
        },
        {
          :button       => "zone_collect_logs",
          :icon         => "fa fa-filter fa-lg",
          :text         => N_("Collect all logs"),
          :title        => N_("Collect all logs from the selected \#{ui_lookup(:table=>\"zone\")}"),
        },
      ]
    },
    {
      :button       => "zone_log_depot_edit",
      :icon         => "pficon pficon-edit fa-lg",
      :text         => N_("Edit"),
      :title        => N_("Edit the Log Depot settings for the selected \#{ui_lookup(:table=>\"zone\")}"),
    },
  ])
end
