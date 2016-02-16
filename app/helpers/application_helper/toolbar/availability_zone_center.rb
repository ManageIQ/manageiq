class ApplicationHelper::Toolbar::AvailabilityZoneCenter < ApplicationHelper::Toolbar::Basic
  button_group('availability_zone_policy', [
    select(
      :availability_zone_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :items => [
        button(
          :availability_zone_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for this Availability Zone'),
          N_('Edit Tags')),
      ]
    ),
  ])
  button_group('availability_zone_monitoring', [
    select(
      :availability_zone_monitoring_choice,
      'product product-monitoring fa-lg',
      t = N_('Monitoring'),
      t,
      :items => [
        button(
          :availability_zone_perf,
          'product product-monitoring fa-lg',
          N_('Show Capacity & Utilization data for this Availability Zone'),
          N_('Utilization'),
          :url       => "/show",
          :url_parms => "?display=performance"),
        button(
          :availability_zone_timeline,
          'product product-timeline fa-lg',
          N_('Show Timelines for this #{ui_lookup(:table=>"availability_zone")}'),
          N_('Timelines'),
          :url       => "/show",
          :url_parms => "?display=timeline"),
      ]
    ),
  ])
end
