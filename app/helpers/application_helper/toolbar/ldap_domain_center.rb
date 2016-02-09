class ApplicationHelper::Toolbar::LdapDomainCenter < ApplicationHelper::Toolbar::Basic
  button_group('ldap_domain_vmdb', [
    {
      :buttonSelect => "scan_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "ldap_domain_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit this LDAP Domain"),
          :title        => N_("Edit this LDAP Domain"),
        },
        {
          :button       => "ldap_domain_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Delete this LDAP Domain"),
          :title        => N_("Delete this LDAP Domain"),
          :url_parms    => "&refresh=y",
          :confirm      => N_("Are you sure you want to delete this LDAP Domain?"),
        },
      ]
    },
  ])
end
