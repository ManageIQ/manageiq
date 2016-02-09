class ApplicationHelper::Toolbar::ContainerRoutesCenter < ApplicationHelper::Toolbar::Basic
  button_group('container_route_vmdb', [
    {
      :buttonSelect => "container_route_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "container_route_new",
          :icon         => "pficon pficon-add-circle-o fa-lg",
          :url          => "/new",
          :text         => N_("Add a New \#{ui_lookup(:table=>\"container_project\")}"),
          :title        => N_("Add a New \#{ui_lookup(:table=>\"container_project\")}"),
        },
        {
          :button       => "container_service_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Selected \#{ui_lookup(:table=>\"container_project\")}"),
          :title        => N_("Select a single \#{ui_lookup(:table=>\"container_project\")} to edit"),
          :url_parms    => "main_div",
          :onwhen       => "1",
        },
        {
          :button       => "container_service_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove \#{ui_lookup(:tables=>\"container_project\")} from the VMDB"),
          :title        => N_("Remove selected \#{ui_lookup(:tables=>\"container_projects\")} from the VMDB"),
          :url_parms    => "main_div",
          :confirm      => N_("Warning: The selected \#{ui_lookup(:tables=>\"container_projects\")} and ALL of their components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove the selected \#{ui_lookup(:tables=>\"container_projects\")}?"),
          :onwhen       => "1+",
        },
      ]
    },
  ])
  button_group('container_route_policy', [
    {
      :buttonSelect => "container_route_policy_choice",
      :icon         => "fa fa-shield fa-lg",
      :title        => N_("Policy"),
      :text         => N_("Policy"),
      :enabled      => "false",
      :onwhen       => "1+",
      :items => [
        {
          :button       => "container_route_tag",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Tags"),
          :title        => N_("Edit Tags for this \#{ui_lookup(:table=>\"container_routes\")}"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1+",
        },
      ]
    },
  ])
end
