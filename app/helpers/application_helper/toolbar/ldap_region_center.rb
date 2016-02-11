class ApplicationHelper::Toolbar::LdapRegionCenter < ApplicationHelper::Toolbar::Basic
  button_group('ldap_region_vmdb', [
    select(
      :ldap_region_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :ldap_domain_add,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Add a new LDAP Domain'),
          t),
        button(
          :ldap_region_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit this LDAP Region'),
          t),
        button(
          :ldap_region_delete,
          'pficon pficon-delete fa-lg',
          t = N_('Delete this LDAP Region'),
          t,
          :url_parms => "&refresh=y",
          :confirm   => N_("Are you sure you want to delete this LDAP Region?")),
      ]
    ),
  ])
end
