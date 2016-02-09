class ApplicationHelper::Toolbar::ContainerImageCenter < ApplicationHelper::Toolbar::Basic
  button_group('container_image_vmdb', [
    {
      :buttonSelect => "container_image_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "container_image_scan",
          :icon         => "fa fa-search fa-lg",
          :text         => N_("Perform SmartState Analysis"),
          :title        => N_("Perform SmartState Analysis on this item"),
          :confirm      => N_("Perform SmartState Analysis on this item?"),
        },
      ]
    },
  ])
  button_group('container_image_policy', [
    {
      :buttonSelect => "container_image_policy_choice",
      :icon         => "fa fa-shield fa-lg",
      :title        => N_("Policy"),
      :text         => N_("Policy"),
      :items => [
        {
          :button       => "container_image_tag",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Tags"),
          :title        => N_("Edit Tags for this \#{ui_lookup(:table=>\"container_image\")}"),
        },
      ]
    },
  ])
end
