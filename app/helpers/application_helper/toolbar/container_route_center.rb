class ApplicationHelper::Toolbar::ContainerRouteCenter < ApplicationHelper::Toolbar::Basic
  button_group('container_route_vmdb', [
    select(
      :container_route_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :container_route_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit this Route'),
          t,
          :url => "/edit"),
        button(
          :container_route_delete,
          'pficon pficon-delete fa-lg',
          t = N_('Remove this Route from the VMDB'),
          t,
          :url_parms => "&refresh=y",
          :confirm   => N_("Warning: This Route and ALL of its components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this Route?")),
      ]
    ),
  ])
  button_group('container_route_policy', [
    select(
      :container_route_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :items => [
        button(
          :container_route_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for this Route'),
          N_('Edit Tags')),
      ]
    ),
  ])
end
