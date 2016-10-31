class ApplicationHelper::Toolbar::ServicetemplatecatalogsCenter < ApplicationHelper::Toolbar::Basic
  button_group('st_catalog_vmdb', [
    select(
      :st_catalog_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :st_catalog_new,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Add a New Catalog'),
          t),
        button(
          :st_catalog_edit,
          'pficon pficon-edit fa-lg',
          N_('Select a single Item to edit'),
          N_('Edit Selected Item'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1"),
        button(
          :st_catalog_delete,
          'pficon pficon-delete fa-lg',
          N_('Remove selected Catalogs'),
          N_('Remove Catalogs'),
          :url_parms => "main_div",
          :confirm   => N_("Warning: The selected Catalogs will be permanently removed!"),
          :enabled   => false,
          :onwhen    => "1+"),
      ]
    ),
  ])
end
