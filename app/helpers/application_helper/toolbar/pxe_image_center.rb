class ApplicationHelper::Toolbar::PxeImageCenter < ApplicationHelper::Toolbar::Basic
  button_group('pxe_image_vmdb', [
    {
      :buttonSelect => "pxe_image_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "pxe_image_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit this PXE Image"),
          :title        => N_("Edit this PXE Image"),
        },
      ]
    },
  ])
end
