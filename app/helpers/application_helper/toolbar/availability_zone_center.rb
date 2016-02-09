class ApplicationHelper::Toolbar::AvailabilityZoneCenter < ApplicationHelper::Toolbar::Basic
  button_group('availability_zone_policy', [
    {
      :buttonSelect => "availability_zone_policy_choice",
      :icon         => "fa fa-shield fa-lg",
      :title        => N_("Policy"),
      :text         => N_("Policy"),
      :items => [
        {
          :button       => "availability_zone_tag",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Tags"),
          :title        => N_("Edit Tags for this Availability Zone"),
        },
      ]
    },
  ])
  button_group('availability_zone_monitoring', [
    {
      :buttonSelect => "availability_zone_monitoring_choice",
      :icon         => "product product-monitoring fa-lg",
      :title        => N_("Monitoring"),
      :text         => N_("Monitoring"),
      :items => [
        {
          :button       => "availability_zone_perf",
          :icon         => "product product-monitoring fa-lg",
          :text         => N_("Utilization"),
          :title        => N_("Show Capacity & Utilization data for this Availability Zone"),
          :url          => "/show",
          :url_parms    => "?display=performance",
        },
        {
          :button       => "availability_zone_timeline",
          :icon         => "product product-timeline fa-lg",
          :text         => N_("Timelines"),
          :title        => N_("Show Timelines for this \#{ui_lookup(:table=>\"availability_zone\")}"),
          :url          => "/show",
          :url_parms    => "?display=timeline",
        },
      ]
    },
  ])
end
