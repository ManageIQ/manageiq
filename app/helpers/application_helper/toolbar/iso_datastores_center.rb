class ApplicationHelper::Toolbar::IsoDatastoresCenter < ApplicationHelper::Toolbar::Basic
  button_group('iso_datastore_vmdb', [
    {
      :buttonSelect => "iso_datastore_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "iso_datastore_new",
          :icon         => "pficon pficon-add-circle-o fa-lg",
          :text         => N_("Add a New ISO Datastore"),
          :title        => N_("Add a New ISO Datastore"),
        },
        {
          :button       => "iso_datastore_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove ISO Datastores from the VMDB"),
          :title        => N_("Remove selected ISO Datastores from the VMDB"),
          :url_parms    => "main_div",
          :confirm      => N_("Warning: The selected ISO Datastores and ALL of their components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove the selected ISO Datastores?"),
          :enabled      => "false",
          :onwhen       => "1+",
        },
        {
          :separator    => nil,
        },
        {
          :button       => "iso_datastore_refresh",
          :icon         => "fa fa-refresh fa-lg",
          :text         => N_("Refresh Relationships"),
          :title        => N_("Refresh Relationships for selected ISO Datastores"),
          :url_parms    => "main_div",
          :confirm      => N_("Refresh Relationships for selected ISO Datastores?"),
          :enabled      => "false",
          :onwhen       => "1+",
        },
      ]
    },
  ])
end
