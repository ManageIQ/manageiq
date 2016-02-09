class ApplicationHelper::Toolbar::MiqReportSchedulesCenter < ApplicationHelper::Toolbar::Basic
  button_group('miq_schedule_vmdb', [
    {
      :buttonSelect => "miq_schedule_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "miq_report_schedule_add",
          :icon         => "pficon pficon-add-circle-o fa-lg",
          :text         => N_("Add a new Schedule"),
          :title        => N_("Add a new Schedule"),
        },
        {
          :button       => "miq_report_schedule_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit the selected Schedule"),
          :title        => N_("Edit the selected Schedule"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1",
        },
        {
          :button       => "miq_report_schedule_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Delete the selected Schedules from the VMDB"),
          :title        => N_("Delete the selected Schedules from the VMDB"),
          :url_parms    => "main_div",
          :confirm      => N_("Warning: The selected Schedules and ALL of their components will be permanently removed from the VMDB.  Are you sure you want to delete the selected Schedules?"),
          :enabled      => "false",
          :onwhen       => "1+",
        },
        {
          :button       => "miq_report_schedule_enable",
          :icon         => "fa fa-check fa-lg",
          :text         => N_("Enable the selected Schedules"),
          :title        => N_("Enable the selected Schedules"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1+",
        },
        {
          :button       => "miq_report_schedule_disable",
          :icon         => "fa fa-ban fa-lg",
          :text         => N_("Disable the selected Schedules"),
          :title        => N_("Disable the selected Schedules"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1+",
        },
        {
          :separator    => nil,
        },
        {
          :button       => "miq_report_schedule_run_now",
          :icon         => "fa fa-cog fa-lg",
          :text         => N_("Queue up selected Schedules to run now"),
          :title        => N_("Queue up selected Schedules to run now"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1+",
        },
      ]
    },
  ])
end
