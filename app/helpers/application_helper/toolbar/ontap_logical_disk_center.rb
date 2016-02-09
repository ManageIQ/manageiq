class ApplicationHelper::Toolbar::OntapLogicalDiskCenter < ApplicationHelper::Toolbar::Basic
  button_group('ontap_logical_disk_policy', [
    {
      :buttonSelect => "ontap_logical_disk_policy_choice",
      :icon         => "fa fa-shield fa-lg",
      :title        => N_("Policy"),
      :text         => N_("Policy"),
      :items => [
        {
          :button       => "ontap_logical_disk_tag",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Tags"),
          :title        => N_("Edit Tags for this Logical Disk"),
        },
      ]
    },
  ])
  button_group('ontap_logical_disk_monitoring', [
    {
      :buttonSelect => "ontap_logical_disk_monitoring_choice",
      :icon         => "product product-monitoring fa-lg",
      :title        => N_("Monitoring"),
      :text         => N_("Monitoring"),
      :items => [
        {
          :button       => "ontap_logical_disk_perf",
          :icon         => "product product-monitoring fa-lg",
          :text         => N_("Utilization"),
          :title        => N_("Show Capacity & Utilization data for this Logical Disk"),
          :url          => "/show",
          :url_parms    => "?display=performance",
        },
        {
          :button       => "ontap_logical_disk_statistics",
          :icon         => "product product-monitoring fa-lg",
          :text         => N_("Statistics"),
          :title        => N_("Show Utilization Statistics for this Logical Disk"),
          :url          => "/show_statistics",
        },
      ]
    },
  ])
end
