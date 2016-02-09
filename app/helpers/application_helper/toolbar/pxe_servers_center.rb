class ApplicationHelper::Toolbar::PxeServersCenter < ApplicationHelper::Toolbar::Basic
  button_group('pxe_server_vmdb', [
    {
      :buttonSelect => "pxe_server_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "pxe_server_new",
          :icon         => "pficon pficon-add-circle-o fa-lg",
          :text         => N_("Add a New PXE Server"),
          :title        => N_("Add a New PXE Server"),
        },
        {
          :button       => "pxe_server_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Selected PXE Servers"),
          :title        => N_("Select a single PXE Servers to edit"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1",
        },
        {
          :button       => "pxe_server_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove PXE Servers from the VMDB"),
          :title        => N_("Remove selected PXE Servers from the VMDB"),
          :url_parms    => "main_div",
          :confirm      => N_("Warning: The selected PXE Servers and ALL of their components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove the selected PXE Servers?"),
          :enabled      => "false",
          :onwhen       => "1+",
        },
        {
          :separator    => nil,
        },
        {
          :button       => "pxe_server_refresh",
          :icon         => "fa fa-refresh fa-lg",
          :text         => N_("Refresh Relationships"),
          :title        => N_("Refresh Relationships for selected PXE Servers"),
          :url_parms    => "main_div",
          :confirm      => N_("Refresh Relationships for selected PXE Servers?"),
          :enabled      => "false",
          :onwhen       => "1+",
        },
      ]
    },
  ])
end
