class ApplicationHelper::Toolbar::PxeImageTypesCenter < ApplicationHelper::Toolbar::Basic
  button_group('pxe_image_type_vmdb', [
    {
      :buttonSelect => "pxe_image_type_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "pxe_image_type_new",
          :icon         => "pficon pficon-add-circle-o fa-lg",
          :text         => N_("Add a new System Image Type"),
          :title        => N_("Add a new System Image Type"),
        },
        {
          :button       => "pxe_image_type_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit the selected System Image Type"),
          :title        => N_("Select a single System Image Type to edit"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1",
        },
        {
          :button       => "pxe_image_type_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove System Image Types from the VMDB"),
          :title        => N_("Remove selected System Image Types from the VMDB"),
          :url_parms    => "main_div",
          :confirm      => N_("Warning: The selected System Image Types will be permanently removed from the Virtual Management Database.  Are you sure you want to remove the selected System Image Types?"),
          :enabled      => "false",
          :onwhen       => "1+",
        },
      ]
    },
  ])
end
