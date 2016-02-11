class ApplicationHelper::Toolbar::LdapDomainCenter < ApplicationHelper::Toolbar::Basic
  button_group('ldap_domain_vmdb', [
    select(
      :scan_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :ldap_domain_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit this LDAP Domain'),
          t),
        button(
          :ldap_domain_delete,
          'pficon pficon-delete fa-lg',
          t = N_('Delete this LDAP Domain'),
          t,
          :url_parms => "&refresh=y",
          :confirm   => N_("Are you sure you want to delete this LDAP Domain?")),
      ]
    ),
  ])
end
