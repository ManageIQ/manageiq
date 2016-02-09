class ApplicationHelper::Toolbar::CustomButtonCenter < ApplicationHelper::Toolbar::Basic
  button_group('custom_button_vmdb', [
    {
      :buttonSelect => "custom_button_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "ab_button_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit this Button"),
          :title        => N_("Edit this Button"),
          :url_parms    => "main_div",
        },
        {
          :button       => "ab_button_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove this Button"),
          :title        => N_("Remove this Button"),
          :url_parms    => "main_div",
          :confirm      => N_("Warning: This Button will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this Button?"),
        },
        {
          :separator    => nil,
        },
        {
          :button       => "ab_button_simulate",
          :icon         => "fa fa-play-circle-o fa-lg",
          :text         => N_("Simulate"),
          :title        => N_("Simulate using Button details"),
          :url          => "resolve",
          :url_parms    => "?button=simulate",
        },
      ]
    },
  ])
end
