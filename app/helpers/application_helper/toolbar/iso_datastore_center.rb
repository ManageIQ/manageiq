class ApplicationHelper::Toolbar::IsoDatastoreCenter < ApplicationHelper::Toolbar::Basic
  button_group('iso_datastore_vmdb', [
    select(
      :iso_datastore_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :iso_datastore_delete,
          'pficon pficon-delete fa-lg',
          t = N_('Remove this ISO Datastore from the VMDB'),
          t,
          :url_parms => "&refresh=y",
          :confirm   => N_("Warning: This ISO Datastore and ALL of its components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this ISO Datastore?")),
        separator,
        button(
          :iso_datastore_refresh,
          'fa fa-refresh fa-lg',
          N_('Refresh Relationships for this ISO Datastore'),
          N_('Refresh Relationships'),
          :confirm => N_("Refresh Relationships for this ISO Datastore?")),
      ]
    ),
  ])
end
