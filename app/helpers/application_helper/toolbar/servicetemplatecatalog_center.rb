class ApplicationHelper::Toolbar::ServicetemplatecatalogCenter < ApplicationHelper::Toolbar::Basic
  button_group('st_catalog_vmdb', [
    {
      :buttonSelect => "st_catalog_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :onwhen       => "1+",
      :items => [
        {
          :button       => "st_catalog_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit this Item"),
          :title        => N_("Edit this Item"),
          :url_parms    => "main_div",
        },
        {
          :button       => "st_catalog_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove Item from the VMDB"),
          :title        => N_("Remove this Item from the VMDB"),
          :url_parms    => "main_div",
          :confirm      => N_("Warning: This Catalog will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this Catalog?"),
        },
      ]
    },
  ])
end
