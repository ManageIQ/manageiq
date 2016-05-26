class ApplicationHelper::Toolbar::StorageCenter < ApplicationHelper::Toolbar::Basic
  button_group('storage_vmdb', [
    select(
      :storage_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :storage_scan,
          'fa fa-search fa-lg',
          N_('Perform SmartState Analysis on this #{ui_lookup(:table=>"storages")}'),
          N_('Perform SmartState Analysis'),
          :confirm => N_("Perform SmartState Analysis on this \#{ui_lookup(:table=>\"storages\")}?")),
        separator,
        button(
          :storage_delete,
          'pficon pficon-delete fa-lg',
          N_('Remove this #{ui_lookup(:table=>"storages")} from the VMDB'),
          N_('Remove from the VMDB'),
          :url_parms => "&refresh=y",
          :confirm   => N_("Warning: This \#{ui_lookup(:table=>\"storages\")} and ALL of its components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this \#{ui_lookup(:table=>\"storages\")}?")),
      ]
    ),
  ])
  button_group('storage_policy', [
    select(
      :storage_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :items => [
        button(
          :storage_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for this #{ui_lookup(:table=>"storages")}'),
          N_('Edit Tags')),
      ]
    ),
  ])
  button_group('storage_monitoring', [
    select(
      :storage_monitoring_choice,
      'product product-monitoring fa-lg',
      t = N_('Monitoring'),
      t,
      :items => [
        button(
          :storage_perf,
          'product product-monitoring fa-lg',
          N_('Show Capacity & Utilization data for this #{ui_lookup(:table=>"storages")}'),
          N_('Utilization'),
          :url       => "/show",
          :url_parms => "?display=performance"),
      ]
    ),
  ])
end
