class ApplicationHelper::Toolbar::PxeImageTypeCenter < ApplicationHelper::Toolbar::Basic
  button_group('pxe_image_type_vmdb', [
    {
      :buttonSelect => "pxe_image_type_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "pxe_image_type_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit this System Image Type"),
          :title        => N_("Edit this System Image Type"),
        },
        {
          :button       => "pxe_image_type_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove this System Image Type from the VMDB"),
          :title        => N_("Remove this System Image Type from the VMDB"),
          :url_parms    => "&refresh=y",
          :confirm      => N_("Warning: This System Image Type will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this System Image Type?"),
        },
      ]
    },
  ])
end
