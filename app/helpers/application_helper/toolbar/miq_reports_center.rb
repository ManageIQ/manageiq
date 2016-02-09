class ApplicationHelper::Toolbar::MiqReportsCenter < ApplicationHelper::Toolbar::Basic
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
      ]
    },
  ])
end
