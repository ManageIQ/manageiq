class ApplicationHelper::Toolbar::MiqActionCenter < ApplicationHelper::Toolbar::Basic
  button_group('miq_action_vmdb', [
    {
      :buttonSelect => "miq_action_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "action_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit this Action"),
          :title        => N_("Edit this Action"),
          :url_parms    => "?type=basic",
        },
        {
          :button       => "action_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Delete this Action"),
          :title        => N_("Delete this Action"),
          :url_parms    => "main_div",
          :confirm      => N_("Are you sure you want to delete this Action?"),
        },
      ]
    },
  ])
end
