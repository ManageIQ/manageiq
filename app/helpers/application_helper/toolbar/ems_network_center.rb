class ApplicationHelper::Toolbar::EmsNetworkCenter < ApplicationHelper::Toolbar::Basic
  button_group('ems_network_vmdb', [
    button(
      :refresh_server_summary,
      'fa fa-repeat fa-lg',
      N_('Reload Current Display'),
      nil),
    select(
      :ems_network_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :ems_network_refresh,
          'fa fa-refresh fa-lg',
          N_('Refresh relationships and power states for all items related to this #{ui_lookup(:table=>"ems_network")}'),
          N_('Refresh Relationships and Power States'),
          :confirm => N_("Refresh relationships and power states for all items related to this \#{ui_lookup(:table=>\"ems_network\")}?")),
        separator,
        button(
          :ems_network_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit this #{ui_lookup(:table=>"ems_network")}'),
          t,
          :full_path => "<%= edit_ems_network_path(@ems) %>"),
        button(
          :ems_network_delete,
          'pficon pficon-delete fa-lg',
          t = N_('Remove this #{ui_lookup(:table=>"ems_network")} from the VMDB'),
          t,
          :url_parms => "&refresh=y",
          :confirm   => N_("Warning: This \#{ui_lookup(:table=>\"ems_network\")} and ALL of its components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this \#{ui_lookup(:table=>\"ems_network\")}?")),
      ]
    ),
  ])
  button_group('ems_network_policy', [
    select(
      :ems_network_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :items => [
        button(
          :ems_network_protect,
          'pficon pficon-edit fa-lg',
          N_('Manage Policies for this #{ui_lookup(:table=>"ems_network")}'),
          N_('Manage Policies')),
        button(
          :ems_network_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for this #{ui_lookup(:table=>"ems_network")}'),
          N_('Edit Tags')),
      ]
    ),
  ])
  button_group('ems_network_monitoring', [
    select(
      :ems_network_monitoring_choice,
      'product product-monitoring fa-lg',
      t = N_('Monitoring'),
      t,
      :items => [
        button(
          :ems_network_timeline,
          'product product-timeline fa-lg',
          N_('Show Timelines for this #{ui_lookup(:table=>"ems_network")}'),
          N_('Timelines'),
          :url       => "/show",
          :url_parms => "?display=timeline"),
      ]
    ),
  ])
end
