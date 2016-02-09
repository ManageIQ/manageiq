class ApplicationHelper::Toolbar::ContainerNodeCenter < ApplicationHelper::Toolbar::Basic
  button_group('container_node_vmdb', [
    {
      :buttonSelect => "container_node_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "container_node_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit this \#{ui_lookup(:table=>\"container_node\")}"),
          :title        => N_("Edit this \#{ui_lookup(:table=>\"container_node\")}"),
          :url          => "/edit",
        },
        {
          :button       => "container_node_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove this \#{ui_lookup(:table=>\"container_node\")} from the VMDB"),
          :title        => N_("Remove this \#{ui_lookup(:table=>\"container_node\")} from the VMDB"),
          :url_parms    => "&refresh=y",
          :confirm      => N_("Warning: This \#{ui_lookup(:table=>\"container_node\")} and ALL of its components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this \#{ui_lookup(:table=>\"container_node\")}?"),
        },
      ]
    },
  ])
  button_group('container_node_monitoring', [
    {
      :buttonSelect => "container_node_monitoring_choice",
      :icon         => "product product-monitoring fa-lg",
      :title        => N_("Monitoring"),
      :text         => N_("Monitoring"),
      :items => [
        {
          :button       => "container_node_perf",
          :icon         => "product product-monitoring fa-lg",
          :text         => N_("Utilization"),
          :title        => N_("Show Capacity & Utilization data for this Node"),
          :url          => "/show",
          :url_parms    => "?display=performance",
        },
        {
          :button       => "container_node_timeline",
          :icon         => "product product-timeline fa-lg",
          :text         => N_("Timelines"),
          :title        => N_("Show Timelines for this Node"),
          :url          => "/show",
          :url_parms    => "?display=timeline",
        },
      ]
    },
  ])
  button_group('container_node_policy', [
    {
      :buttonSelect => "container_node_policy_choice",
      :icon         => "fa fa-shield fa-lg",
      :title        => N_("Policy"),
      :text         => N_("Policy"),
      :items => [
        {
          :button       => "container_node_tag",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Tags"),
          :title        => N_("Edit Tags for this \#{ui_lookup(:table=>\"container_node\")}"),
        },
      ]
    },
  ])
end
