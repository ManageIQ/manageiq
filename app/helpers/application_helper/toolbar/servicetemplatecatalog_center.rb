class ApplicationHelper::Toolbar::ServicetemplatecatalogCenter < ApplicationHelper::Toolbar::Basic
  button_group('st_catalog_vmdb', [
    select(:st_catalog_vmdb_choice, 'fa fa-cog fa-lg', N_('Configuration'), N_('Configuration'),
      :onwhen    => "1+",
      :items     => [
        button(:st_catalog_edit, 'pficon pficon-edit fa-lg', N_('Edit this Item'), N_('Edit this Item'),
          :url_parms => "main_div"),
        button(:st_catalog_delete, 'pficon pficon-delete fa-lg', N_('Remove this Item from the VMDB'), N_('Remove Item from the VMDB'),
          :url_parms => "main_div",
          :confirm   => N_("Warning: This Catalog will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this Catalog?")),
      ]
    ),
  ])
end
