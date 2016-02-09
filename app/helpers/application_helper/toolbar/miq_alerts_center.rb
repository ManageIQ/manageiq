class ApplicationHelper::Toolbar::MiqAlertsCenter < ApplicationHelper::Toolbar::Basic
  button_group('miq_alert_vmdb', [
    {
      :buttonSelect => "miq_alert_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "alert_new",
          :icon         => "pficon pficon-add-circle-o fa-lg",
          :text         => N_("Add a New Alert"),
          :title        => N_("Add a New Alert"),
        },
      ]
    },
  ])
end
