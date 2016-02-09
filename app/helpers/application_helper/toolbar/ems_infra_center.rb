class ApplicationHelper::Toolbar::EmsInfraCenter < ApplicationHelper::Toolbar::Basic
  button_group('ems_infra_vmdb', [
    select(:ems_infra_vmdb_choice, 'fa fa-cog fa-lg', N_('Configuration'), N_('Configuration'),
      :items     => [
        button(:ems_infra_refresh, 'fa fa-refresh fa-lg', N_('Refresh relationships and power states for all items related to this #{ui_lookup(:table=>"ems_infra")}'), N_('Refresh Relationships and Power States'),
          :confirm   => N_("Refresh relationships and power states for all items related to this \#{ui_lookup(:table=>\"ems_infra\")}?")),
        separator,
        button(:ems_infra_edit, 'pficon pficon-edit fa-lg', N_('Edit this #{ui_lookup(:table=>"ems_infra")}'), N_('Edit this #{ui_lookup(:table=>"ems_infra")}'),
          :url       => "/edit"),
        button(:ems_infra_scale, 'pficon pficon-edit fa-lg', N_('Scale this #{ui_lookup(:table=>"ems_infra")}'), N_('Scale this #{ui_lookup(:table=>"ems_infra")}'),
          :url       => "/scaling"),
        button(:ems_infra_delete, 'pficon pficon-delete fa-lg', N_('Remove this #{ui_lookup(:table=>"ems_infra")} from the VMDB'), N_('Remove this #{ui_lookup(:table=>"ems_infra")} from the VMDB'),
          :url_parms => "&refresh=y",
          :confirm   => N_("Warning: This \#{ui_lookup(:table=>\"ems_infra\")} and ALL of its components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this \#{ui_lookup(:table=>\"ems_infra\")}?")),
      ]
    ),
  ])
  button_group('ems_infra_policy', [
    select(:ems_infra_policy_choice, 'fa fa-shield fa-lg', N_('Policy'), N_('Policy'),
      :items     => [
        button(:ems_infra_protect, 'pficon pficon-edit fa-lg', N_('Manage Policies for this #{ui_lookup(:table=>"ems_infra")}'), N_('Manage Policies')),
        button(:ems_infra_tag, 'pficon pficon-edit fa-lg', N_('Edit Tags for this #{ui_lookup(:table=>"ems_infra")}'), N_('Edit Tags')),
      ]
    ),
  ])
  button_group('ems_infra_monitoring', [
    select(:ems_infra_monitoring_choice, 'product product-monitoring fa-lg', N_('Monitoring'), N_('Monitoring'),
      :items     => [
        button(:ems_infra_timeline, 'product product-timeline fa-lg', N_('Show Timelines for this #{ui_lookup(:table=>"ems_infra")}'), N_('Timelines'),
          :url       => "/show",
          :url_parms => "?display=timeline"),
      ]
    ),
  ])
end
