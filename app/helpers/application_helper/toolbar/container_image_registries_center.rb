class ApplicationHelper::Toolbar::ContainerImageRegistriesCenter < ApplicationHelper::Toolbar::Basic
  button_group('container_image_registry_vmdb', [
    select(
      :container_image_registry_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :container_image_registry_new,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Add a New Image Registry'),
          t,
          :url => "/new"),
        button(
          :container_image_registry_edit,
          'pficon pficon-edit fa-lg',
          N_('Select a single Image Registry to edit'),
          N_('Edit Selected Image Registry'),
          :url_parms => "main_div",
          :onwhen    => "1"),
        button(
          :container_image_registry_delete,
          'pficon pficon-delete fa-lg',
          N_('Remove selected Image Registries from the VMDB'),
          N_('Remove Image Registries from the VMDB'),
          :url_parms => "main_div",
          :confirm   => N_("Warning: The selected Image Registries and ALL of their components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove the selected Image Registries?"),
          :onwhen    => "1+"),
      ]
    ),
  ])
  button_group('container_image_registry_policy', [
    select(
      :container_image_registry_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :enabled => false,
      :onwhen  => "1+",
      :items   => [
        button(
          :container_image_registry_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for these Image Registries'),
          N_('Edit Tags'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1+"),
      ]
    ),
  ])
end
