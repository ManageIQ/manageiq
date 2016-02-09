class ApplicationHelper::Toolbar::LdapDomainCenter < ApplicationHelper::Toolbar::Basic
  button_group('ldap_domain_vmdb', [
    select(:scan_vmdb_choice, 'fa fa-cog fa-lg', N_('Configuration'), N_('Configuration'),
      :items     => [
        button(:ldap_domain_edit, 'pficon pficon-edit fa-lg', N_('Edit this LDAP Domain'), N_('Edit this LDAP Domain')),
        button(:ldap_domain_delete, 'pficon pficon-delete fa-lg', N_('Delete this LDAP Domain'), N_('Delete this LDAP Domain'),
          :url_parms => "&refresh=y",
          :confirm   => N_("Are you sure you want to delete this LDAP Domain?")),
      ]
    ),
  ])
end
