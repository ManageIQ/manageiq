class ApplicationHelper::Toolbar::MiqActionsCenter < ApplicationHelper::Toolbar::Basic
  button_group('miq_action_vmdb', [
    {
      :buttonSelect => "miq_action_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "action_new",
          :icon         => "pficon pficon-add-circle-o fa-lg",
          :text         => N_("Add a new Action"),
          :title        => N_("Add a new Action"),
        },
      ]
    },
  ])
end
