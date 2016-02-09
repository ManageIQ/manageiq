class ApplicationHelper::Toolbar::PxeServerCenter < ApplicationHelper::Toolbar::Basic
  button_group('pxe_server_vmdb', [
    {
      :buttonSelect => "pxe_server_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "pxe_server_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit this PXE Server"),
          :title        => N_("Edit this PXE Server"),
        },
        {
          :button       => "pxe_server_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove this PXE Server from the VMDB"),
          :title        => N_("Remove this PXE Server from the VMDB"),
          :url_parms    => "&refresh=y",
          :confirm      => N_("Warning: This PXE Server and ALL of its components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this PXE Server?"),
        },
        {
          :separator    => nil,
        },
        {
          :button       => "pxe_server_refresh",
          :icon         => "fa fa-refresh fa-lg",
          :text         => N_("Refresh Relationships"),
          :title        => N_("Refresh Relationships for this PXE Server"),
          :confirm      => N_("Refresh Relationships for this PXE Server?"),
        },
      ]
    },
  ])
end
