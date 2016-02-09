class ApplicationHelper::Toolbar::ServicetemplatecatalogsCenter < ApplicationHelper::Toolbar::Basic
  button_group('st_catalog_vmdb', [
    {
      :buttonSelect => "st_catalog_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "st_catalog_new",
          :icon         => "pficon pficon-add-circle-o fa-lg",
          :text         => N_("Add a New Catalog"),
          :title        => N_("Add a New Catalog"),
        },
        {
          :button       => "st_catalog_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Selected Item"),
          :title        => N_("Select a single Item to edit"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1",
        },
        {
          :button       => "st_catalog_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove Items from the VMDB"),
          :title        => N_("Remove selected Items from the VMDB"),
          :url_parms    => "main_div",
          :confirm      => N_("Warning: The selected Items will be permanently removed from the Virtual Management Database.  Are you sure you want to remove the selected Items?"),
          :enabled      => "false",
          :onwhen       => "1+",
        },
      ]
    },
  ])
end
