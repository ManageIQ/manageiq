class ApplicationHelper::Toolbar::MiddlewareServersCenter < ApplicationHelper::Toolbar::Basic
  button_group('middleware_server_vmdb', [
    select(
      :middleware_server_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :middleware_server_new,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Add a New #{ui_lookup(:table=>"middleware_server")}'),
          t,
          :url => "/new"),
        button(
          :middleware_server_edit,
          'pficon pficon-edit fa-lg',
          N_('Select a single #{ui_lookup(:table=>"middleware_server")} to edit'),
          N_('Edit Selected #{ui_lookup(:table=>"middleware_server")}'),
          :url_parms => "main_div",
          :onwhen    => "1"),
        button(
          :middleware_server_delete,
          'pficon pficon-delete fa-lg',
          N_('Remove selected #{ui_lookup(:tables=>"middleware_servers")} from the VMDB'),
          N_('Remove #{ui_lookup(:tables=>"middleware_servers")} from the VMDB'),
          :url_parms => "main_div",
          :confirm   => N_("Warning: The selected \#{ui_lookup(:tables=>\"middleware_servers\")} and ALL of their components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove the selected \#{ui_lookup(:tables=>\"middleware_servers\")}?"),
          :onwhen    => "1+"),
      ]
    ),
  ])
  button_group('middleware_server_policy', [
    select(
      :middleware_server_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :enabled => "false",
      :onwhen  => "1+",
      :items   => [
        button(
          :middleware_server_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for this #{ui_lookup(:table=>"middleware_servers")}'),
          N_('Edit Tags'),
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "1+"),
      ]
    ),
  ])
end
