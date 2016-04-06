class ApplicationHelper::Toolbar::EmsMiddlewaresCenter < ApplicationHelper::Toolbar::Basic
  button_group('ems_middleware_vmdb', [
    select(
      :ems_middleware_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :ems_middleware_new,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Add a New #{ui_lookup(:table=>"ems_middleware")}'),
          t,
          :url => "/new"),
        button(
          :ems_middleware_edit,
          'pficon pficon-edit fa-lg',
          N_('Select a single #{ui_lookup(:table=>"ems_middleware")} to edit'),
          N_('Edit Selected #{ui_lookup(:table=>"ems_middleware")}'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1"),
        button(
          :ems_middleware_delete,
          'pficon pficon-delete fa-lg',
          N_('Remove selected #{ui_lookup(:tables=>"ems_middlewares")} from the VMDB'),
          N_('Remove #{ui_lookup(:tables=>"ems_middlewares")} from the VMDB'),
          :url_parms => "main_div",
          :confirm   => N_("Warning: The selected \#{ui_lookup(:tables=>\"ems_middlewares\")} and ALL of their components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove the selected \#{ui_lookup(:tables=>\"ems_middlewares\")}?"),
          :enabled   => false,
          :onwhen    => "1+"),
      ]
    ),
  ])
  button_group('ems_middleware_policy', [
    select(
      :ems_middleware_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :enabled => false,
      :onwhen  => "1+",
      :items   => [
        button(
          :ems_middleware_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for this #{ui_lookup(:table=>"ems_middleware")}'),
          N_('Edit Tags'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1+"),
      ]
    ),
  ])
end
