class ApplicationHelper::Toolbar::EmsNetworksCenter < ApplicationHelper::Toolbar::Basic
  button_group('ems_network_vmdb', [
    select(
      :ems_network_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :ems_network_refresh,
          'fa fa-refresh fa-lg',
          N_('Refresh relationships and power states for all items related to the selected #{ui_lookup(:tables=>"ems_networks")}'),
          N_('Refresh Relationships and Power States'),
          :url_parms => "main_div",
          :confirm   => N_("Refresh relationships and power states for all items related to the selected \#{ui_lookup(:tables=>\"ems_networks\")}?"),
          :enabled   => "false",
          :onwhen    => "1+"),
        button(
          :ems_network_discover,
          'fa fa-search fa-lg',
          t = N_('Discover #{ui_lookup(:tables=>"ems_networks")}'),
          t,
          :url       => "/discover",
          :url_parms => "?discover_type=ems"),
        separator,
        button(
          :ems_network_new,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Add a New #{ui_lookup(:table=>"ems_network")}'),
          t,
          :url => "/new"),
        button(
          :ems_network_edit,
          'pficon pficon-edit fa-lg',
          N_('Select a single #{ui_lookup(:table=>"ems_network")} to edit'),
          N_('Edit Selected #{ui_lookup(:table=>"ems_network")}'),
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "1"),
        button(
          :ems_network_delete,
          'pficon pficon-delete fa-lg',
          N_('Remove selected #{ui_lookup(:tables=>"ems_networks")} from the VMDB'),
          N_('Remove #{ui_lookup(:tables=>"ems_networks")} from the VMDB'),
          :url_parms => "main_div",
          :confirm   => N_("Warning: The selected \#{ui_lookup(:tables=>\"ems_networks\")} and ALL of their components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove the selected \#{ui_lookup(:tables=>\"ems_networks\")}?"),
          :enabled   => "false",
          :onwhen    => "1+"),
      ]
    ),
  ])
  button_group('ems_network_policy', [
    select(
      :ems_network_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :enabled => "false",
      :onwhen  => "1+",
      :items   => [
        button(
          :ems_network_protect,
          'pficon pficon-edit fa-lg',
          N_('Manage Policies for the selected #{ui_lookup(:tables=>"ems_networks")}'),
          N_('Manage Policies'),
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "1+"),
        button(
          :ems_network_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for the selected #{ui_lookup(:tables=>"ems_networks")}'),
          N_('Edit Tags'),
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "1+"),
      ]
    ),
  ])
end
