class ApplicationHelper::Toolbar::StorageCenter < ApplicationHelper::Toolbar::Basic
  button_group('storage_vmdb', [
    {
      :buttonSelect => "storage_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "storage_scan",
          :icon         => "fa fa-search fa-lg",
          :text         => N_("Perform SmartState Analysis"),
          :title        => N_("Perform SmartState Analysis on this \#{ui_lookup(:table=>\"storages\")}"),
          :confirm      => N_("Perform SmartState Analysis on this \#{ui_lookup(:table=>\"storages\")}?"),
        },
        {
          :separator    => nil,
        },
        {
          :button       => "storage_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove from the VMDB"),
          :title        => N_("Remove this \#{ui_lookup(:table=>\"storages\")} from the VMDB"),
          :url_parms    => "&refresh=y",
          :confirm      => N_("Warning: This \#{ui_lookup(:table=>\"storages\")} and ALL of its components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this \#{ui_lookup(:table=>\"storages\")}?"),
        },
      ]
    },
  ])
  button_group('storage_policy', [
    {
      :buttonSelect => "storage_policy_choice",
      :icon         => "fa fa-shield fa-lg",
      :title        => N_("Policy"),
      :text         => N_("Policy"),
      :items => [
        {
          :button       => "storage_tag",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Tags"),
          :title        => N_("Edit Tags for this \#{ui_lookup(:table=>\"storages\")}"),
        },
      ]
    },
  ])
  button_group('storage_monitoring', [
    {
      :buttonSelect => "storage_monitoring_choice",
      :icon         => "product product-monitoring fa-lg",
      :title        => N_("Monitoring"),
      :text         => N_("Monitoring"),
      :items => [
        {
          :button       => "storage_perf",
          :icon         => "product product-monitoring fa-lg",
          :text         => N_("Utilization"),
          :title        => N_("Show Capacity & Utilization data for this \#{ui_lookup(:table=>\"storages\")}"),
          :url          => "/show",
          :url_parms    => "?display=performance",
        },
      ]
    },
  ])
end
