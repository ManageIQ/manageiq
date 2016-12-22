class ApplicationHelper::Toolbar::IsoDatastoresCenter < ApplicationHelper::Toolbar::Basic
  button_group('iso_datastore_vmdb', [
    select(
      :iso_datastore_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :iso_datastore_new,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Add a New ISO Datastore'),
          t,
          :klass => ApplicationHelper::Button::ButtonNewDiscover),
        button(
          :iso_datastore_delete,
          'pficon pficon-delete fa-lg',
          N_('Remove selected ISO Datastores'),
          N_('Remove ISO Datastores'),
          :url_parms => "main_div",
          :confirm   => N_("Warning: The selected ISO Datastores and ALL of their components will be permanently removed!"),
          :enabled   => false,
          :onwhen    => "1+"),
        separator,
        button(
          :iso_datastore_refresh,
          'fa fa-refresh fa-lg',
          N_('Refresh Relationships for selected ISO Datastores'),
          N_('Refresh Relationships'),
          :url_parms => "main_div",
          :confirm   => N_("Refresh Relationships for selected ISO Datastores?"),
          :enabled   => false,
          :onwhen    => "1+"),
      ]
    ),
  ])
end
