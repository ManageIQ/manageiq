class ApplicationHelper::Toolbar::LdapRegionsCenter < ApplicationHelper::Toolbar::Basic
  button_group('ldap_region_vmdb', [
    select(
      :ldap_region_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :ldap_region_add,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Add a new LDAP Region'),
          t),
        button(
          :ldap_region_edit,
          'pficon pficon-edit fa-lg',
          N_('Select a single LDAP Region to edit'),
          N_('Edit the selected LDAP Region'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1"),
        button(
          :ldap_region_delete,
          'pficon pficon-delete fa-lg',
          N_('Select one or more LDAP Regions to delete'),
          N_('Delete selected LDAP Regions'),
          :url_parms => "main_div",
          :confirm   => N_("Delete all selected LDAP Regions?"),
          :enabled   => false,
          :onwhen    => "1+"),
      ]
    ),
  ])
end
