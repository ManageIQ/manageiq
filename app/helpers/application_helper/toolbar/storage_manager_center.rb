class ApplicationHelper::Toolbar::StorageManagerCenter < ApplicationHelper::Toolbar::Basic
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
          N_('Refresh Inventory for all Storage CIs known to this Storage Manager'),
          N_('Refresh Inventory'),
          :confirm => N_("Refresh Inventory for all Storage CIs known to this Storage Manager?")),
        button(
          :storage_manager_refresh_status,
          'fa fa-refresh fa-lg',
          N_('Refresh Status for all Storage CIs known to this Storage Manager'),
          N_('Refresh Status'),
          :confirm => N_("Refresh Status for all Storage CIs known to this Storage Manager?")),
        separator,
        button(
          :storage_manager_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit this Storage Manager'),
          t,
          :url => "/edit"),
        button(
          :storage_manager_delete,
          'pficon pficon-delete fa-lg',
          t = N_('Remove this Storage Manager from the VMDB'),
          t,
          :url_parms => "&refresh=y",
          :confirm   => N_("Warning: This Storage Manager and ALL of its components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this Storage Manager?")),
      ]
    ),
  ])
end
