class ApplicationHelper::Toolbar::LdapRegionCenter < ApplicationHelper::Toolbar::Basic
  button_group('ldap_region_vmdb', [
    {
      :buttonSelect => "ldap_region_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "ldap_domain_add",
          :icon         => "pficon pficon-add-circle-o fa-lg",
          :text         => N_("Add a new LDAP Domain"),
          :title        => N_("Add a new LDAP Domain"),
        },
        {
          :button       => "ldap_region_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit this LDAP Region"),
          :title        => N_("Edit this LDAP Region"),
        },
        {
          :button       => "ldap_region_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Delete this LDAP Region"),
          :title        => N_("Delete this LDAP Region"),
          :url_parms    => "&refresh=y",
          :confirm      => N_("Are you sure you want to delete this LDAP Region?"),
        },
      ]
    },
  ])
end
