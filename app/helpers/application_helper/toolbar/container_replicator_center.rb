class ApplicationHelper::Toolbar::ContainerReplicatorCenter < ApplicationHelper::Toolbar::Basic
  button_group('container_replicator_vmdb', [
    select(
      :container_replicator_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :container_replicator_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit this Replicator'),
          t,
          :url => "/edit"),
        button(
          :container_replicator_delete,
          'pficon pficon-delete fa-lg',
          t = N_('Remove this Replicator from the VMDB'),
          t,
          :url_parms => "&refresh=y",
          :confirm   => N_("Warning: This Replicator and ALL of its components will be permanently removed!")),
      ]
    ),
  ])
  button_group('container_replicator_monitoring', [
    select(
      :container_replicator_monitoring_choice,
      'product product-monitoring fa-lg',
      t = N_('Monitoring'),
      t,
      :items => [
        button(
          :container_replicator_timeline,
          'product product-timeline fa-lg',
          N_('Show Timelines for this Replicator'),
          N_('Timelines'),
          :url       => "/show",
          :url_parms => "?display=timeline",
          :options   => {:entity => 'Replicator'},
          :klass     => ApplicationHelper::Button::ContainerTimeline),
        button(
          :container_replicator_perf,
          'product product-monitoring fa-lg',
          N_('Show Capacity & Utilization data for this Replicator'),
          N_('Utilization'),
          :url       => "/show",
          :url_parms => "?display=performance"),
      ]
    ),
  ])
  button_group('container_replicator_policy', [
    select(
      :container_replicator_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :items => [
        button(
          :container_replicator_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for this Replicator'),
          N_('Edit Tags')),
        button(
          :container_replicator_protect,
          'pficon pficon-edit fa-lg',
          N_('Manage Policies for this Replicator'),
          N_('Manage Policies')),
        button(
          :container_replicator_check_compliance,
          'fa fa-search fa-lg',
          N_('Check Compliance of the last known configuration for this Replicator'),
          N_('Check Compliance of Last Known Configuration'),
          :confirm => N_("Initiate Check Compliance of the last known configuration for this item?")),
      ]
    ),
  ])
end
