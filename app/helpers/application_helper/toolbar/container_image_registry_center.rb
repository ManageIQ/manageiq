class ApplicationHelper::Toolbar::ContainerImageRegistryCenter < ApplicationHelper::Toolbar::Basic
  button_group('container_image_registry_vmdb', [
    select(
      :container_image_registry_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :container_image_registry_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit this #{ui_lookup(:table=>"container_image_registry")}'),
          t,
          :url => "/edit"),
        button(
          :container_image_registry_delete,
          'pficon pficon-delete fa-lg',
          t = N_('Remove this #{ui_lookup(:table=>"container_image_registry")} from the VMDB'),
          t,
          :url_parms => "&refresh=y",
          :confirm   => N_("Warning: This \#{ui_lookup(:table=>\"container_image_registry\")} and ALL of its components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this \#{ui_lookup(:table=>\"container_image_registry\")}?")),
      ]
    ),
  ])
  button_group('container_image_registry_policy', [
    select(
      :container_image_registry_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :items => [
        button(
          :container_image_registry_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for this #{ui_lookup(:table=>"container_image_registry")}'),
          N_('Edit Tags')),
      ]
    ),
  ])
end
