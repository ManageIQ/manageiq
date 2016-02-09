class ApplicationHelper::Toolbar::CustomButtonSetCenter < ApplicationHelper::Toolbar::Basic
  button_group('custom_button_set_vmdb', [
    {
      :buttonSelect => "custom_button_set_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "ab_group_new",
          :icon         => "pficon pficon-add-circle-o fa-lg",
          :text         => N_("Add a new Button Group"),
          :title        => N_("Add a new Button Group"),
        },
        {
          :button       => "ab_button_new",
          :icon         => "pficon pficon-add-circle-o fa-lg",
          :text         => N_("Add a new Button"),
          :title        => N_("Add a new Button"),
        },
        {
          :button       => "ab_group_reorder",
          :icon         => "pficon pficon-edit fa-lg-assign",
          :text         => N_("Reorder"),
          :title        => N_("Reorder \#{x_active_tree == :ab_tree ? \"Buttons Groups\" : \"Buttons and Groups\"}"),
        },
      ]
    },
  ])
end
