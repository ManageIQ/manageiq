class ApplicationHelper::Toolbar::CustomButtonsCenter < ApplicationHelper::Toolbar::Basic
  button_group('custom_button_vmdb', [
    {
      :buttonSelect => "custom_button_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "ab_group_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit this Button Group"),
          :title        => N_("Edit this Button Group"),
          :url_parms    => "main_div",
        },
        {
          :button       => "ab_button_new",
          :icon         => "pficon pficon-add-circle-o fa-lg",
          :text         => N_("Add a new Button"),
          :title        => N_("Add a new Button"),
        },
        {
          :button       => "ab_group_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove this Button Group"),
          :title        => N_("Remove this Button Group"),
          :url_parms    => "main_div",
          :confirm      => N_("Warning: The selected Button Group will be permanently removed.  Are you sure you want to remove the selected Button Group?"),
        },
      ]
    },
  ])
end
