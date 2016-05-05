class ApplicationHelper::Toolbar::EmsContainerCenter < ApplicationHelper::Toolbar::Basic
  button_group('ems_container_vmdb', [
    button(
      :refresh_server_summary,
      'fa fa-repeat fa-lg',
      N_('Reload Current Display'),
      nil),
    select(
      :ems_container_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :ems_container_refresh,
          'fa fa-refresh fa-lg',
          N_('Refresh items and relationships related to this #{ui_lookup(:table=>"ems_container")}'),
          N_('Refresh items and relationships'),
          :confirm => N_("Refresh items and relationships related to this \#{ui_lookup(:table=>\"ems_container\")}?")),
        separator,
        button(
          :ems_container_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit this #{ui_lookup(:table=>"ems_container")}'),
          t,),
        button(
          :ems_container_delete,
          'pficon pficon-delete fa-lg',
          t = N_('Remove this #{ui_lookup(:table=>"ems_container")} from the VMDB'),
          t,
          :url_parms => "&refresh=y",
          :confirm   => N_("Warning: This \#{ui_lookup(:table=>\"ems_container\")} and ALL of its components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this \#{ui_lookup(:table=>\"ems_container\")}?")),
      ]
    ),
  ])
  button_group('ems_container_monitoring', [
    select(
      :ems_container_monitoring_choice,
      'product product-monitoring fa-lg',
      t = N_('Monitoring'),
      t,
      :items => [
        button(
          :ems_container_perf,
          'product product-monitoring fa-lg',
          N_('Show Capacity & Utilization data for this Provider'),
          N_('Utilization')),
        button(
          :ems_container_timeline,
          'product product-timeline fa-lg',
          N_('Show Timelines for this #{ui_lookup(:table=>"ems_container")}'),
          N_('Timelines')),
      ]
    ),
  ])
  button_group('ems_container_policy', [
    select(
      :ems_container_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :items => [
        button(
          :ems_container_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for this #{ui_lookup(:table=>"ems_container")}'),
          N_('Edit Tags')),
        button(
          :ems_container_protect,
          'pficon pficon-edit fa-lg',
          N_('Manage Policies for this #{ui_lookup(:table=>"ems_container")}'),
          N_('Manage Policies')),
      ]
    ),
  ])
end
