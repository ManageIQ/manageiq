class ApplicationHelper::Toolbar::ContainersCenter < ApplicationHelper::Toolbar::Basic
  button_group('container_vmdb', [
    {
      :buttonSelect => "container_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "container_new",
          :icon         => "pficon pficon-add-circle-o fa-lg",
          :url          => "/new",
          :text         => N_("Add a New \#{ui_lookup(:table=>\"container\")}"),
          :title        => N_("Add a New \#{ui_lookup(:table=>\"container\")}"),
        },
        {
          :button       => "container_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Selected \#{ui_lookup(:table=>\"container\")}"),
          :title        => N_("Select a single \#{ui_lookup(:table=>\"container\")} to edit"),
          :url_parms    => "main_div",
          :onwhen       => "1",
        },
        {
          :button       => "container_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove \#{ui_lookup(:tables=>\"containers\")} from the VMDB"),
          :title        => N_("Remove selected \#{ui_lookup(:tables=>\"containers\")} from the VMDB"),
          :url_parms    => "main_div",
          :confirm      => N_("Warning: The selected \#{ui_lookup(:tables=>\"containers\")} and ALL of their components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove the selected \#{ui_lookup(:tables=>\"containers\")}?"),
          :onwhen       => "1+",
        },
      ]
    },
  ])
  button_group('container_policy', [
    {
      :buttonSelect => "container_policy_choice",
      :icon         => "fa fa-shield fa-lg",
      :title        => N_("Policy"),
      :text         => N_("Policy"),
      :enabled      => "false",
      :onwhen       => "1+",
      :items => [
        {
          :button       => "container_tag",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Tags"),
          :title        => N_("Edit Tags for selected \#{ui_lookup(:tables=>\"container\")}"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1+",
        },
      ]
    },
  ])
end
