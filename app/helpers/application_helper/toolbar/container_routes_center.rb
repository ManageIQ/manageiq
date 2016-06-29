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
          t = N_('Add a New Project'),
          t,
          :url => "/new"),
        button(
          :container_service_edit,
          'pficon pficon-edit fa-lg',
          N_('Select a single Project to edit'),
          N_('Edit Selected Project'),
          :url_parms => "main_div",
          :onwhen    => "1"),
        button(
          :container_service_delete,
          'pficon pficon-delete fa-lg',
          N_('Remove selected Projects from the VMDB'),
          N_('Remove Projects from the VMDB'),
          :url_parms => "main_div",
          :confirm   => N_("Warning: The selected Projects and ALL of their components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove the selected Projects?"),
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
          N_('Edit Tags for these Routes'),
          N_('Edit Tags'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1+"),
      ]
    ),
  ])
end
