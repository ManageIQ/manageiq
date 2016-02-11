class ApplicationHelper::Toolbar::ContainerServicesCenter < ApplicationHelper::Toolbar::Basic
  button_group('container_service_vmdb', [
    select(
      :container_service_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :container_service_new,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Add a New #{ui_lookup(:table=>"container_service")}'),
          t,
          :url => "/new"),
        button(
          :container_service_edit,
          'pficon pficon-edit fa-lg',
          N_('Select a single #{ui_lookup(:table=>"container_service")} to edit'),
          N_('Edit Selected #{ui_lookup(:table=>"container_service")}'),
          :url_parms => "main_div",
          :onwhen    => "1"),
        button(
          :container_service_delete,
          'pficon pficon-delete fa-lg',
          N_('Remove selected #{ui_lookup(:tables=>"container_services")} from the VMDB'),
          N_('Remove #{ui_lookup(:tables=>"container_services")} from the VMDB'),
          :url_parms => "main_div",
          :confirm   => N_("Warning: The selected \#{ui_lookup(:tables=>\"container_services\")} and ALL of their components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove the selected \#{ui_lookup(:tables=>\"container_services\")}?"),
          :onwhen    => "1+"),
      ]
    ),
  ])
  button_group('container_service_policy', [
    select(
      :container_service_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :enabled => "false",
      :onwhen  => "1+",
      :items   => [
        button(
          :container_service_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for this #{ui_lookup(:table=>"container_services")}'),
          N_('Edit Tags'),
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "1+"),
      ]
    ),
  ])
end
