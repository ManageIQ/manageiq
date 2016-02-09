class ApplicationHelper::Toolbar::ContainerCenter < ApplicationHelper::Toolbar::Basic
  button_group('container_vmdb', [
    {
      :buttonSelect => "container_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "container_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit this \#{ui_lookup(:table=>\"container\")}"),
          :title        => N_("Edit this \#{ui_lookup(:table=>\"container\")}"),
          :url          => "/edit",
        },
        {
          :button       => "container_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove this \#{ui_lookup(:table=>\"container\")} from the VMDB"),
          :title        => N_("Remove this \#{ui_lookup(:table=>\"container\")} from the VMDB"),
          :url_parms    => "&refresh=y",
          :confirm      => N_("Warning: This \#{ui_lookup(:table=>\"container\")} and ALL of its components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this \#{ui_lookup(:table=>\"container\")}?"),
        },
      ]
    },
  ])
  button_group('container_policy', [
    {
      :buttonSelect => "container_policy_choice",
      :icon         => "fa fa-shield fa-lg",
      :title        => N_("Policy"),
      :text         => N_("Policy"),
      :items => [
        {
          :button       => "container_tag",
          :icon         => "pficon pficon-edit fa-lg",
          :url_parms    => "main_div",
          :text         => N_("Edit Tags"),
          :title        => N_("Edit Tags for this \#{ui_lookup(:table=>\"container\")}"),
        },
      ]
    },
  ])
  button_group('container_monitoring', [
    {
      :buttonSelect => "container_monitoring_choice",
      :icon         => "product product-monitoring fa-lg",
      :title        => N_("Monitoring"),
      :text         => N_("Monitoring"),
      :items => [
        {
          :button       => "container_timeline",
          :icon         => "product product-timeline fa-lg",
          :text         => N_("Timelines"),
          :title        => N_("Show Timelines for this Container"),
          :url_parms    => "?display=timeline",
        },
        {
          :button       => "container_perf",
          :icon         => "product product-monitoring fa-lg",
          :text         => N_("Utilization"),
          :title        => N_("Show Capacity & Utilization data for this Container"),
          :url_parms    => "?display=performance",
        },
      ]
    },
  ])
end
