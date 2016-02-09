class ApplicationHelper::Toolbar::ContainerGroupCenter < ApplicationHelper::Toolbar::Basic
  button_group('container_group_vmdb', [
    select(:container_group_vmdb_choice, 'fa fa-cog fa-lg', N_('Configuration'), N_('Configuration'),
      :items     => [
        button(:container_group_edit, 'pficon pficon-edit fa-lg', N_('Edit this #{ui_lookup(:table=>"container_group")}'), N_('Edit this #{ui_lookup(:table=>"container_group")}'),
          :url       => "/edit"),
        button(:container_group_delete, 'pficon pficon-delete fa-lg', N_('Remove this #{ui_lookup(:table=>"container_group")} from the VMDB'), N_('Remove this #{ui_lookup(:table=>"container_group")} from the VMDB'),
          :url_parms => "&refresh=y",
          :confirm   => N_("Warning: This \#{ui_lookup(:table=>\"container_group\")} and ALL of its components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this \#{ui_lookup(:table=>\"container_group\")}?")),
      ]
    ),
  ])
  button_group('container_group_monitoring', [
    select(:container_group_monitoring_choice, 'product product-monitoring fa-lg', N_('Monitoring'), N_('Monitoring'),
      :items     => [
        button(:container_group_timeline, 'product product-timeline fa-lg', N_('Show Timelines for this Group'), N_('Timelines'),
          :url       => "/show",
          :url_parms => "?display=timeline"),
        button(:container_group_perf, 'product product-monitoring fa-lg', N_('Show Capacity & Utilization data for this Group'), N_('Utilization'),
          :url       => "/show",
          :url_parms => "?display=performance"),
      ]
    ),
  ])
  button_group('container_group_policy', [
    select(:container_group_policy_choice, 'fa fa-shield fa-lg', N_('Policy'), N_('Policy'),
      :items     => [
        button(:container_group_tag, 'pficon pficon-edit fa-lg', N_('Edit Tags for this #{ui_lookup(:table=>"container_group")}'), N_('Edit Tags')),
      ]
    ),
  ])
end
