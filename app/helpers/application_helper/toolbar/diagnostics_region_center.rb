class ApplicationHelper::Toolbar::DiagnosticsRegionCenter < ApplicationHelper::Toolbar::Basic
  button_group('support_reloading', [
    button(
      :reload_server_tree,
      'fa fa-repeat fa-lg',
      N_('Reload Current Display'),
      nil),
  ])
  button_group('ldap_domain_vmdb', [
    select(
      :support_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :delete_server,
          'pficon pficon-delete fa-lg',
          t = N_('Delete Server #{@record.name} [#{@record.id}]'),
          t,
          :confirm => N_("Do you want to delete Server \#{@record.name} [\#{@record.id}]?")),
        button(
          :role_start,
          'fa fa-play-circle-o fa-lg',
          N_('Start the #{@record.server_role.description} Role on Server #{@record.miq_server.name} [#{@record.miq_server.id}]'),
          N_('Start Role'),
          :confirm => N_("Start the \#{@record.server_role.description} Role on Server \#{@record.miq_server.name} [\#{@record.miq_server.id}]?")),
        button(
          :role_suspend,
          'fa fa-pause-circle-o fa-lg',
          N_('Suspend the #{@record.server_role.description} Role on Server #{@record.miq_server.name} [#{@record.miq_server.id}]'),
          N_('Suspend Role'),
          :confirm => N_("Suspend the \#{@record.server_role.description} Role on Server \#{@record.miq_server.name} [\#{@record.miq_server.id}]?")),
        button(
          :demote_server,
          'pficon pficon-delete fa-lg_master',
          N_('Demote Server #{@record.miq_server.name} [#{@record.miq_server.id}] to secondary for the #{@record.server_role.description} Role'),
          N_('Demote Server'),
          :confirm => N_("Do you want to demote this Server to secondary?  This will leave no primary Server for this Role.")),
        button(
          :promote_server,
          'product product-migrate fa-lg',
          N_('Promote Server #{@record.miq_server.name} [#{@record.miq_server.id}] to primary for the #{@record.server_role.description} Role'),
          N_('Promote Server'),
          :confirm => N_("Do you want to promote this Server to primary?  This will replace any existing primary Server for this Role.")),
      ]
    ),
  ])
end
