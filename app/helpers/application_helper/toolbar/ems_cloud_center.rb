class ApplicationHelper::Toolbar::EmsCloudCenter < ApplicationHelper::Toolbar::Basic
  button_group('ems_cloud_vmdb', [
    select(:ems_cloud_vmdb_choice, 'fa fa-cog fa-lg', N_('Configuration'), N_('Configuration'),
      :items     => [
        button(:ems_cloud_refresh, 'fa fa-refresh fa-lg', N_('Refresh relationships and power states for all items related to this #{ui_lookup(:table=>"ems_cloud")}'), N_('Refresh Relationships and Power States'),
          :confirm   => N_("Refresh relationships and power states for all items related to this \#{ui_lookup(:table=>\"ems_cloud\")}?")),
        separator,
        button(:ems_cloud_edit, 'pficon pficon-edit fa-lg', N_('Edit this #{ui_lookup(:table=>"ems_cloud")}'), N_('Edit this #{ui_lookup(:table=>"ems_cloud")}'),
          :full_path => "<%= edit_ems_cloud_path(@ems) %>"),
        button(:ems_cloud_delete, 'pficon pficon-delete fa-lg', N_('Remove this #{ui_lookup(:table=>"ems_cloud")} from the VMDB'), N_('Remove this #{ui_lookup(:table=>"ems_cloud")} from the VMDB'),
          :url_parms => "&refresh=y",
          :confirm   => N_("Warning: This \#{ui_lookup(:table=>\"ems_cloud\")} and ALL of its components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this \#{ui_lookup(:table=>\"ems_cloud\")}?")),
      ]
    ),
  ])
  button_group('ems_cloud_policy', [
    select(:ems_cloud_policy_choice, 'fa fa-shield fa-lg', N_('Policy'), N_('Policy'),
      :items     => [
        button(:ems_cloud_protect, 'pficon pficon-edit fa-lg', N_('Manage Policies for this #{ui_lookup(:table=>"ems_cloud")}'), N_('Manage Policies')),
        button(:ems_cloud_tag, 'pficon pficon-edit fa-lg', N_('Edit Tags for this #{ui_lookup(:table=>"ems_cloud")}'), N_('Edit Tags')),
      ]
    ),
  ])
  button_group('ems_cloud_monitoring', [
    select(:ems_cloud_monitoring_choice, 'product product-monitoring fa-lg', N_('Monitoring'), N_('Monitoring'),
      :items     => [
        button(:ems_cloud_timeline, 'product product-timeline fa-lg', N_('Show Timelines for this #{ui_lookup(:table=>"ems_cloud")}'), N_('Timelines'),
          :url_parms => "?display=timeline"),
      ]
    ),
  ])
end
