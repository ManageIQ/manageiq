class ApplicationHelper::Toolbar::MiqEventCenter < ApplicationHelper::Toolbar::Basic
  button_group('policy_vmdb', [
    {
      :buttonSelect => "policy_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "event_edit",
          :icon         => "pficon pficon-edit fa-lg-action",
          :text         => N_("Edit Actions for this Policy Event"),
          :title        => N_("Edit Actions for this Policy Event"),
          :url_parms    => "main_div",
        },
      ]
    },
  ])
end
