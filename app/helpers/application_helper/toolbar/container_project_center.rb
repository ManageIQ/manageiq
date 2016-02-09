class ApplicationHelper::Toolbar::ContainerProjectCenter < ApplicationHelper::Toolbar::Basic
  button_group('container_project_vmdb', [
    {
      :buttonSelect => "container_project_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "container_project_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit this \#{ui_lookup(:table=>\"container_project\")}"),
          :title        => N_("Edit this \#{ui_lookup(:table=>\"container_project\")}"),
          :url          => "/edit",
        },
        {
          :button       => "container_project_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove this \#{ui_lookup(:table=>\"container_project\")} from the VMDB"),
          :title        => N_("Remove this \#{ui_lookup(:table=>\"container_project\")} from the VMDB"),
          :url_parms    => "&refresh=y",
          :confirm      => N_("Warning: This \#{ui_lookup(:table=>\"container_project\")} and ALL of its components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this \#{ui_lookup(:table=>\"container_project\")}?"),
        },
      ]
    },
  ])
  button_group('container_project_monitoring', [
    {
      :buttonSelect => "container_project_monitoring_choice",
      :icon         => "product product-monitoring fa-lg",
      :title        => N_("Monitoring"),
      :text         => N_("Monitoring"),
      :items => [
        {
          :button       => "container_project_timeline",
          :icon         => "product product-timeline fa-lg",
          :text         => N_("Timelines"),
          :title        => N_("Show Timelines for this Project"),
          :url          => "/show",
          :url_parms    => "?display=timeline",
        },
        {
          :button       => "container_project_perf",
          :icon         => "product product-monitoring fa-lg",
          :text         => N_("Utilization"),
          :title        => N_("Show Capacity & Utilization data for this Project"),
          :url          => "/show",
          :url_parms    => "?display=performance",
        },
      ]
    },
  ])
  button_group('container_project_policy', [
    {
      :buttonSelect => "container_project_policy_choice",
      :icon         => "fa fa-shield fa-lg",
      :title        => N_("Policy"),
      :text         => N_("Policy"),
      :items => [
        {
          :button       => "container_project_tag",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Tags"),
          :title        => N_("Edit Tags for this \#{ui_lookup(:table=>\"container_project\")}"),
        },
      ]
    },
  ])
end
