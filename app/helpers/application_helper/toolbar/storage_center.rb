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
          N_('Perform SmartState Analysis on this Datastore'),
          N_('Perform SmartState Analysis'),
          :confirm => N_("Perform SmartState Analysis on this Datastore?")),
        separator,
        button(
          :storage_delete,
          'pficon pficon-delete fa-lg',
          N_('Remove this Datastore from the VMDB'),
          N_('Remove from the VMDB'),
          :url_parms => "&refresh=y",
          :confirm   => N_("Warning: This Datastore and ALL of its components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this Datastore?")),
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
          N_('Edit Tags for this Datastore'),
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
          N_('Show Capacity & Utilization data for this Datastore'),
          N_('Utilization'),
          :url       => "/show",
          :url_parms => "?display=performance"),
      ]
    ),
  ])
end
