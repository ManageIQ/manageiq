class ApplicationHelper::Toolbar::StorageManagersCenter < ApplicationHelper::Toolbar::Basic
  button_group('storage_manager_vmdb', [
    select(
      :storage_manager_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :storage_manager_refresh_inventory,
          'fa fa-refresh fa-lg',
          N_('Refresh Inventory for all Storage CIs known to the selected Storage Managers'),
          N_('Refresh Inventory'),
          :url_parms => "main_div",
          :confirm   => N_("Refresh Inventory for all Storage CIs known to the selected Storage Managers?"),
          :enabled   => "false",
          :onwhen    => "1+"),
        button(
          :storage_manager_refresh_status,
          'fa fa-refresh fa-lg',
          N_('Refresh Status for all Storage CIs known to the selected Storage Managers'),
          N_('Refresh Status'),
          :url_parms => "main_div",
          :confirm   => N_("Refresh Status for all Storage CIs known to the selected Storage Managers?"),
          :enabled   => "false",
          :onwhen    => "1+"),
        separator,
        button(
          :storage_manager_new,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Add a New Storage Manager'),
          t,
          :url => "/new"),
        button(
          :storage_manager_edit,
          'pficon pficon-edit fa-lg',
          N_('Select a single Storage Manager to edit'),
          N_('Edit Selected Storage Manager'),
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "1"),
        button(
          :storage_manager_delete,
          'pficon pficon-delete fa-lg',
          N_('Remove selected Storage Managers from the VMDB'),
          N_('Remove Storage Managers from the VMDB'),
          :url_parms => "main_div",
          :confirm   => N_("Warning: The selected Storage Managers and ALL of their components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove the selected Storage Managers?"),
          :enabled   => "false",
          :onwhen    => "1+"),
      ]
    ),
  ])
end
