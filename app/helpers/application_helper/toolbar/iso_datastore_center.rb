class ApplicationHelper::Toolbar::IsoDatastoreCenter < ApplicationHelper::Toolbar::Basic
  button_group('iso_datastore_vmdb', [
    {
      :buttonSelect => "iso_datastore_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "iso_datastore_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove this ISO Datastore from the VMDB"),
          :title        => N_("Remove this ISO Datastore from the VMDB"),
          :url_parms    => "&refresh=y",
          :confirm      => N_("Warning: This ISO Datastore and ALL of its components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this ISO Datastore?"),
        },
        {
          :separator    => nil,
        },
        {
          :button       => "iso_datastore_refresh",
          :icon         => "fa fa-refresh fa-lg",
          :text         => N_("Refresh Relationships"),
          :title        => N_("Refresh Relationships for this ISO Datastore"),
          :confirm      => N_("Refresh Relationships for this ISO Datastore?"),
        },
      ]
    },
  ])
end
