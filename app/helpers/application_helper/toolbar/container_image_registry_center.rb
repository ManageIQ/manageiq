class ApplicationHelper::Toolbar::ContainerImageRegistryCenter < ApplicationHelper::Toolbar::Basic
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
          N_('Edit Tags for this Image Registry'),
          N_('Edit Tags')),
      ]
    ),
  ])
end
