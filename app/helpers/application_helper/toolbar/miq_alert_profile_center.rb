class ApplicationHelper::Toolbar::MiqAlertProfileCenter < ApplicationHelper::Toolbar::Basic
  button_group('miq_alert_profile_vmdb', [
    {
      :buttonSelect => "miq_alert_profile_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "alert_profile_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit this Alert Profile"),
          :title        => N_("Edit this Alert Profile"),
          :url_parms    => "main_div",
        },
        {
          :button       => "alert_profile_assign",
          :icon         => "pficon pficon-edit fa-lg-assign",
          :text         => N_("Edit assignments for this Alert Profile"),
          :title        => N_("Edit assignments for this Alert Profile"),
          :url_parms    => "main_div",
        },
        {
          :button       => "alert_profile_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Delete this Alert Profile"),
          :title        => N_("Delete this Alert Profile"),
          :url_parms    => "main_div",
          :confirm      => N_("Are you sure you want to delete this Alert Profile?"),
        },
      ]
    },
  ])
end
