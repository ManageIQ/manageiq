class ApplicationHelper::Toolbar::ContainerRouteCenter < ApplicationHelper::Toolbar::Basic
  button_group('container_route_vmdb', [
    {
      :buttonSelect => "container_route_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "container_route_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit this \#{ui_lookup(:table=>\"container_route\")}"),
          :title        => N_("Edit this \#{ui_lookup(:table=>\"container_route\")}"),
          :url          => "/edit",
        },
        {
          :button       => "container_route_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove this \#{ui_lookup(:table=>\"container_route\")} from the VMDB"),
          :title        => N_("Remove this \#{ui_lookup(:table=>\"container_route\")} from the VMDB"),
          :url_parms    => "&refresh=y",
          :confirm      => N_("Warning: This \#{ui_lookup(:table=>\"container_route\")} and ALL of its components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this \#{ui_lookup(:table=>\"container_route\")}?"),
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
      :items => [
        {
          :button       => "container_route_tag",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Tags"),
          :title        => N_("Edit Tags for this \#{ui_lookup(:table=>\"container_route\")}"),
        },
      ]
    },
  ])
end
