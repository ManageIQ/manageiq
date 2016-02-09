class ApplicationHelper::Toolbar::LdapRegionCenter < ApplicationHelper::Toolbar::Basic
  button_group('ldap_region_vmdb', [
    select(:ldap_region_vmdb_choice, 'fa fa-cog fa-lg', N_('Configuration'), N_('Configuration'),
      :items     => [
        button(:ldap_domain_add, 'pficon pficon-add-circle-o fa-lg', N_('Add a new LDAP Domain'), N_('Add a new LDAP Domain')),
        button(:ldap_region_edit, 'pficon pficon-edit fa-lg', N_('Edit this LDAP Region'), N_('Edit this LDAP Region')),
        button(:ldap_region_delete, 'pficon pficon-delete fa-lg', N_('Delete this LDAP Region'), N_('Delete this LDAP Region'),
          :url_parms => "&refresh=y",
          :confirm   => N_("Are you sure you want to delete this LDAP Region?")),
      ]
    ),
  ])
end
