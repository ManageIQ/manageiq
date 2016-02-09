class ApplicationHelper::Toolbar::StorageManagersCenter < ApplicationHelper::Toolbar::Basic
  button_group('storage_manager_vmdb', [
    {
      :buttonSelect => "storage_manager_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "storage_manager_refresh_inventory",
          :icon         => "fa fa-refresh fa-lg",
          :text         => N_("Refresh Inventory"),
          :title        => N_("Refresh Inventory for all Storage CIs known to the selected Storage Managers"),
          :url_parms    => "main_div",
          :confirm      => N_("Refresh Inventory for all Storage CIs known to the selected Storage Managers?"),
          :enabled      => "false",
          :onwhen       => "1+",
        },
        {
          :button       => "storage_manager_refresh_status",
          :icon         => "fa fa-refresh fa-lg",
          :text         => N_("Refresh Status"),
          :title        => N_("Refresh Status for all Storage CIs known to the selected Storage Managers"),
          :url_parms    => "main_div",
          :confirm      => N_("Refresh Status for all Storage CIs known to the selected Storage Managers?"),
          :enabled      => "false",
          :onwhen       => "1+",
        },
        {
          :separator    => nil,
        },
        {
          :button       => "storage_manager_new",
          :icon         => "pficon pficon-add-circle-o fa-lg",
          :url          => "/new",
          :text         => N_("Add a New Storage Manager"),
          :title        => N_("Add a New Storage Manager"),
        },
        {
          :button       => "storage_manager_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Selected Storage Manager"),
          :title        => N_("Select a single Storage Manager to edit"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1",
        },
        {
          :button       => "storage_manager_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove Storage Managers from the VMDB"),
          :title        => N_("Remove selected Storage Managers from the VMDB"),
          :url_parms    => "main_div",
          :confirm      => N_("Warning: The selected Storage Managers and ALL of their components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove the selected Storage Managers?"),
          :enabled      => "false",
          :onwhen       => "1+",
        },
      ]
    },
  ])
end
