class ApplicationHelper::Toolbar::LdapRegionsCenter < ApplicationHelper::Toolbar::Basic
  button_group('ldap_region_vmdb', [
    {
      :buttonSelect => "ldap_region_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "ldap_region_add",
          :icon         => "pficon pficon-add-circle-o fa-lg",
          :text         => N_("Add a new LDAP Region"),
          :title        => N_("Add a new LDAP Region"),
        },
        {
          :button       => "ldap_region_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit the selected LDAP Region"),
          :title        => N_("Select a single LDAP Region to edit"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1",
        },
        {
          :button       => "ldap_region_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Delete selected LDAP Regions"),
          :title        => N_("Select one or more LDAP Regions to delete"),
          :url_parms    => "main_div",
          :confirm      => N_("Delete all selected LDAP Regions?"),
          :enabled      => "false",
          :onwhen       => "1+",
        },
      ]
    },
  ])
end
