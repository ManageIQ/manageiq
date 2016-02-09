class ApplicationHelper::Toolbar::IsoImageCenter < ApplicationHelper::Toolbar::Basic
  button_group('iso_image_vmdb', [
    {
      :buttonSelect => "iso_image_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "iso_image_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit this ISO Image"),
          :title        => N_("Edit this ISO Image"),
        },
      ]
    },
  ])
end
