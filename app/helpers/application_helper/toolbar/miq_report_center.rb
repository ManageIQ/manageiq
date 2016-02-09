class ApplicationHelper::Toolbar::MiqReportCenter < ApplicationHelper::Toolbar::Basic
  button_group('report_run', [
    {
      :button       => "miq_report_run",
      :icon         => "fa fa-cog fa-lg",
      :text         => N_("Queue"),
      :title        => N_("Queue this Report to be generated"),
    },
  ])
  button_group('report_vmdb', [
    {
      :buttonSelect => "report_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "miq_report_new",
          :icon         => "pficon pficon-add-circle-o fa-lg",
          :text         => N_("Add a new Report"),
          :title        => N_("Add a new Report"),
        },
        {
          :button       => "miq_report_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit this Report"),
          :title        => N_("Edit this Report"),
        },
        {
          :button       => "miq_report_copy",
          :icon         => "fa fa-files-o fa-lg",
          :text         => N_("Copy this Report"),
          :title        => N_("Copy this Report"),
        },
        {
          :button       => "saved_report_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Delete this Saved Report from the Database"),
          :title        => N_("Delete this Saved Report from the Database"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1+",
          :confirm      => N_("The selected Saved Reports will be permanently removed from the database. Are you sure you want to delete this saved Report?"),
        },
        {
          :button       => "miq_report_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Delete this Report from the Database"),
          :title        => N_("Delete this Report from the Database"),
          :url_parms    => "&refresh=y",
          :confirm      => N_("The selected Reports will be permanently removed from the database. Are you sure you want to delete this Report?"),
        },
        {
          :button       => "miq_report_schedule_add",
          :icon         => "fa fa-clock-o fa-lg",
          :text         => N_("Add a new Schedule"),
          :title        => N_("Add a new Schedule"),
        },
      ]
    },
  ])
end
