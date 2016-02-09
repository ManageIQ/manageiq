class ApplicationHelper::Toolbar::ContainerServiceCenter < ApplicationHelper::Toolbar::Basic
  button_group('container_service_vmdb', [
    {
      :buttonSelect => "container_service_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "container_service_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit this \#{ui_lookup(:table=>\"container_service\")}"),
          :title        => N_("Edit this \#{ui_lookup(:table=>\"container_service\")}"),
          :url          => "/edit",
        },
        {
          :button       => "container_service_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove this \#{ui_lookup(:table=>\"container_service\")} from the VMDB"),
          :title        => N_("Remove this \#{ui_lookup(:table=>\"container_service\")} from the VMDB"),
          :url_parms    => "&refresh=y",
          :confirm      => N_("Warning: This \#{ui_lookup(:table=>\"container_service\")} and ALL of its components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this \#{ui_lookup(:table=>\"container_service\")}?"),
        },
      ]
    },
  ])
  button_group('container_service_monitoring', [
    {
      :buttonSelect => "container_service_monitoring_choice",
      :icon         => "product product-monitoring fa-lg",
      :title        => N_("Monitoring"),
      :text         => N_("Monitoring"),
      :items => [
        {
          :button       => "container_service_perf",
          :icon         => "product product-monitoring fa-lg",
          :text         => N_("Utilization"),
          :title        => N_("Show Capacity & Utilization data for this Service"),
          :url          => "/show",
          :url_parms    => "?display=performance",
        },
      ]
    },
  ])
  button_group('container_service_policy', [
    {
      :buttonSelect => "container_service_policy_choice",
      :icon         => "fa fa-shield fa-lg",
      :title        => N_("Policy"),
      :text         => N_("Policy"),
      :items => [
        {
          :button       => "container_service_tag",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Tags"),
          :title        => N_("Edit Tags for this \#{ui_lookup(:table=>\"container_service\")}"),
        },
      ]
    },
  ])
end
