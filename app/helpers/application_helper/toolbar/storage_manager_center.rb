class ApplicationHelper::Toolbar::StorageManagerCenter < ApplicationHelper::Toolbar::Basic
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
          :title        => N_("Refresh Inventory for all Storage CIs known to this Storage Manager"),
          :confirm      => N_("Refresh Inventory for all Storage CIs known to this Storage Manager?"),
        },
        {
          :button       => "storage_manager_refresh_status",
          :icon         => "fa fa-refresh fa-lg",
          :text         => N_("Refresh Status"),
          :title        => N_("Refresh Status for all Storage CIs known to this Storage Manager"),
          :confirm      => N_("Refresh Status for all Storage CIs known to this Storage Manager?"),
        },
        {
          :separator    => nil,
        },
        {
          :button       => "storage_manager_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit this Storage Manager"),
          :title        => N_("Edit this Storage Manager"),
          :url          => "/edit",
        },
        {
          :button       => "storage_manager_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove this Storage Manager from the VMDB"),
          :title        => N_("Remove this Storage Manager from the VMDB"),
          :url_parms    => "&refresh=y",
          :confirm      => N_("Warning: This Storage Manager and ALL of its components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this Storage Manager?"),
        },
      ]
    },
  ])
end
