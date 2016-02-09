class ApplicationHelper::Toolbar::DiagnosticsServerCenter < ApplicationHelper::Toolbar::Basic
  button_group('support_reloading', [
    {
      :button       => "refresh_server_summary",
      :icon         => "fa fa-repeat fa-lg",
      :title        => N_("Reload Current Display"),
    },
    {
      :button       => "refresh_workers",
      :icon         => "fa fa-repeat fa-lg",
      :title        => N_("Reload current workers display"),
    },
    {
      :button       => "refresh_audit_log",
      :icon         => "fa fa-repeat fa-lg",
      :title        => N_("Reload the Audit Log Display"),
    },
    {
      :button       => "fetch_audit_log",
      :url          => "/fetch_audit_log",
      :icon         => "fa fa-download fa-lg",
      :title        => N_("Download the Entire Audit Log File"),
    },
    {
      :button       => "refresh_log",
      :icon         => "fa fa-repeat fa-lg",
      :title        => N_("Reload the EVM Log Display"),
    },
    {
      :button       => "fetch_log",
      :url          => "/fetch_log",
      :icon         => "fa fa-download fa-lg",
      :title        => N_("Download the Entire EVM Log File"),
    },
    {
      :button       => "refresh_production_log",
      :icon         => "fa fa-repeat fa-lg",
      :title        => N_("Reload the \#{@sb[:rails_log]} Log Display"),
    },
    {
      :button       => "fetch_production_log",
      :url          => "/fetch_production_log",
      :icon         => "fa fa-download fa-lg",
      :title        => N_("Download the Entire \#{@sb[:rails_log]} Log File"),
    },
  ])
  button_group('ldap_domain_vmdb', [
    {
      :buttonSelect => "support_vmdb_choice",
      :icon         => "fa fa-filter fa-lg",
      :title        => N_("Collect Logs"),
      :text         => N_("Collect"),
      :items => [
        {
          :button       => "collect_current_logs",
          :icon         => "fa fa-filter fa-lg",
          :text         => N_("Collect current logs"),
          :title        => N_("Collect the current logs from the selected \#{ui_lookup(:table=>\"miq_servers\")}"),
        },
        {
          :button       => "collect_logs",
          :icon         => "fa fa-filter fa-lg",
          :text         => N_("Collect all logs"),
          :title        => N_("Collect all logs from the selected \#{ui_lookup(:table=>\"miq_servers\")}"),
        },
      ]
    },
    {
      :button       => "log_depot_edit",
      :icon         => "pficon pficon-edit fa-lg",
      :text         => N_("Edit"),
      :title        => N_("Edit the Log Depot settings for the selected \#{ui_lookup(:table=>\"miq_servers\")}"),
    },
    {
      :buttonSelect => "support_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "restart_server",
          :icon         => "pficon pficon-restart",
          :text         => N_("Restart server"),
          :title        => N_("Restart server"),
          :confirm      => N_("Warning: Server will be restarted, do you want to continue?"),
        },
        {
          :button       => "restart_workers",
          :icon         => "pficon pficon-restart",
          :text         => N_("Restart selected worker"),
          :title        => N_("Select a worker to restart"),
          :confirm      => N_("Warning: Selected node will be restarted, do you want to continue?"),
        },
      ]
    },
  ])
end
