class ApplicationHelper::Toolbar::MiqAlertProfilesCenter < ApplicationHelper::Toolbar::Basic
  button_group('miq_alert_profile_vmdb', [
    {
      :buttonSelect => "miq_alert_profile_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "alert_profile_new",
          :icon         => "pficon pficon-add-circle-o fa-lg",
          :text         => N_("Add a New \#{ui_lookup(:model=>@sb[:folder])} Alert Profile"),
          :title        => N_("Add a New \#{ui_lookup(:model=>@sb[:folder])} Alert Profile"),
        },
      ]
    },
  ])
end
