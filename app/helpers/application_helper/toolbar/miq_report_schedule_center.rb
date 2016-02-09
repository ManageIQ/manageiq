class ApplicationHelper::Toolbar::MiqReportScheduleCenter < ApplicationHelper::Toolbar::Basic
  button_group('miq_schedule_vmdb', [
    {
      :buttonSelect => "miq_schedule_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "miq_report_schedule_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit this Schedule"),
          :title        => N_("Edit this Schedule"),
        },
        {
          :button       => "miq_report_schedule_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Delete this Schedule from the VMDB"),
          :title        => N_("Delete this Schedule from the VMDB"),
          :url_parms    => "&refresh=y",
          :confirm      => N_("Warning: This Schedule and ALL of its components will be permanently removed from the VMDB.  Are you sure you want to delete this Schedule?"),
        },
        {
          :separator    => nil,
        },
        {
          :button       => "miq_report_schedule_run_now",
          :icon         => "fa fa-cog fa-lg",
          :text         => N_("Queue up this Schedule to run now"),
          :title        => N_("Queue up this Schedule to run now"),
        },
      ]
    },
  ])
end
