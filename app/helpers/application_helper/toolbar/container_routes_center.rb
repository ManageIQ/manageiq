class ApplicationHelper::Toolbar::ContainerRoutesCenter < ApplicationHelper::Toolbar::Basic
  button_group('container_route_vmdb', [
    select(
      :container_route_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :container_route_new,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Add a New #{ui_lookup(:table=>"container_project")}'),
          t,
          :url => "/new"),
        button(
          :container_service_edit,
          'pficon pficon-edit fa-lg',
          N_('Select a single #{ui_lookup(:table=>"container_project")} to edit'),
          N_('Edit Selected #{ui_lookup(:table=>"container_project")}'),
          :url_parms => "main_div",
          :onwhen    => "1"),
        button(
          :container_service_delete,
          'pficon pficon-delete fa-lg',
          N_('Remove selected #{ui_lookup(:tables=>"container_projects")} from the VMDB'),
          N_('Remove #{ui_lookup(:tables=>"container_project")} from the VMDB'),
          :url_parms => "main_div",
          :confirm   => N_("Warning: The selected \#{ui_lookup(:tables=>\"container_projects\")} and ALL of their components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove the selected \#{ui_lookup(:tables=>\"container_projects\")}?"),
          :onwhen    => "1+"),
      ]
    ),
  ])
  button_group('container_route_policy', [
    select(
      :container_route_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :enabled => false,
      :onwhen  => "1+",
      :items   => [
        button(
          :container_route_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for this #{ui_lookup(:table=>"container_routes")}'),
          N_('Edit Tags'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1+"),
      ]
    ),
  ])
end
