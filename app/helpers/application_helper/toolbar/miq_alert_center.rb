class ApplicationHelper::Toolbar::MiqAlertCenter < ApplicationHelper::Toolbar::Basic
  button_group('miq_alert_vmdb', [
    {
      :buttonSelect => "miq_alert_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "alert_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit this Alert"),
          :title        => N_("Edit this Alert"),
          :url_parms    => "main_div",
        },
        {
          :button       => "alert_copy",
          :icon         => "fa fa-files-o fa-lg",
          :text         => N_("Copy this Alert"),
          :title        => N_("Copy this Alert"),
          :confirm      => N_("Are you sure you want to copy this Alert?"),
          :url_parms    => "?copy=true",
        },
        {
          :button       => "alert_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Delete this Alert"),
          :title        => N_("Delete this Alert"),
          :url_parms    => "main_div",
          :confirm      => N_("Are you sure you want to delete this Alert?"),
        },
      ]
    },
  ])
end
