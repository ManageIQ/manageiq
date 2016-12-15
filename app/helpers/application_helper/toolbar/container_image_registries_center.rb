class ApplicationHelper::Toolbar::ContainerImageRegistriesCenter < ApplicationHelper::Toolbar::Basic
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
