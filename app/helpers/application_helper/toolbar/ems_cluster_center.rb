class ApplicationHelper::Toolbar::EmsClusterCenter < ApplicationHelper::Toolbar::Basic
  button_group('ems_cluster_vmdb', [
    {
      :buttonSelect => "cluster_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "ems_cluster_scan",
          :icon         => "fa fa-search fa-lg",
          :text         => N_("Perform SmartState Analysis"),
          :title        => N_("Perform SmartState Analysis on this item"),
          :confirm      => N_("Perform SmartState Analysis on this item?"),
        },
        {
          :button       => "ems_cluster_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove from the VMDB"),
          :title        => N_("Remove this item from the VMDB"),
          :url_parms    => "&refresh=y",
          :confirm      => N_("Warning: This item and ALL of its components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this item?"),
        },
      ]
    },
  ])
  button_group('ems_cluster_policy', [
    {
      :buttonSelect => "ems_cluster_policy_choice",
      :icon         => "fa fa-shield fa-lg",
      :title        => N_("Policy"),
      :text         => N_("Policy"),
      :items => [
        {
          :button       => "ems_cluster_protect",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Manage Policies"),
          :title        => N_("Manage Policies for this item"),
        },
        {
          :button       => "ems_cluster_tag",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Tags"),
          :title        => N_("Edit Tags for this item"),
        },
      ]
    },
  ])
  button_group('ems_cluster_monitoring', [
    {
      :buttonSelect => "ems_cluster_monitoring_choice",
      :icon         => "product product-monitoring fa-lg",
      :title        => N_("Monitoring"),
      :text         => N_("Monitoring"),
      :items => [
        {
          :button       => "ems_cluster_perf",
          :icon         => "product product-monitoring fa-lg",
          :text         => N_("Utilization"),
          :title        => N_("Show Capacity & Utilization data for this item"),
          :url          => "/show",
          :url_parms    => "?display=performance",
        },
        {
          :button       => "ems_cluster_timeline",
          :icon         => "product product-timeline fa-lg",
          :text         => N_("Timelines"),
          :title        => N_("Show Timelines for this item"),
          :url          => "/show",
          :url_parms    => "?display=timeline",
        },
      ]
    },
  ])
end
