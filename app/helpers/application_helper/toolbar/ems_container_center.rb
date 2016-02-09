class ApplicationHelper::Toolbar::EmsContainerCenter < ApplicationHelper::Toolbar::Basic
  button_group('ems_container_vmdb', [
    {
      :buttonSelect => "ems_container_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "ems_container_refresh",
          :icon         => "fa fa-refresh fa-lg",
          :text         => N_("Refresh items and relationships"),
          :title        => N_("Refresh items and relationships related to this \#{ui_lookup(:table=>\"ems_container\")}"),
          :confirm      => N_("Refresh items and relationships related to this \#{ui_lookup(:table=>\"ems_container\")}?"),
        },
        {
          :separator    => nil,
        },
        {
          :button       => "ems_container_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit this \#{ui_lookup(:table=>\"ems_container\")}"),
          :title        => N_("Edit this \#{ui_lookup(:table=>\"ems_container\")}"),
          :url          => "/edit",
        },
        {
          :button       => "ems_container_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove this \#{ui_lookup(:table=>\"ems_container\")} from the VMDB"),
          :title        => N_("Remove this \#{ui_lookup(:table=>\"ems_container\")} from the VMDB"),
          :url_parms    => "&refresh=y",
          :confirm      => N_("Warning: This \#{ui_lookup(:table=>\"ems_container\")} and ALL of its components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this \#{ui_lookup(:table=>\"ems_container\")}?"),
        },
      ]
    },
  ])
  button_group('ems_container_monitoring', [
    {
      :buttonSelect => "ems_container_monitoring_choice",
      :icon         => "product product-monitoring fa-lg",
      :title        => N_("Monitoring"),
      :text         => N_("Monitoring"),
      :items => [
        {
          :button       => "ems_container_perf",
          :icon         => "product product-monitoring fa-lg",
          :text         => N_("Utilization"),
          :title        => N_("Show Capacity & Utilization data for this Provider"),
          :url          => "/show",
          :url_parms    => "?display=performance",
        },
        {
          :button       => "ems_container_timeline",
          :icon         => "product product-timeline fa-lg",
          :text         => N_("Timelines"),
          :title        => N_("Show Timelines for this \#{ui_lookup(:table=>\"ems_container\")}"),
          :url          => "/show",
          :url_parms    => "?display=timeline",
        },
      ]
    },
  ])
  button_group('ems_container_policy', [
    {
      :buttonSelect => "ems_container_policy_choice",
      :icon         => "fa fa-shield fa-lg",
      :title        => N_("Policy"),
      :text         => N_("Policy"),
      :items => [
        {
          :button       => "ems_container_tag",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Tags"),
          :title        => N_("Edit Tags for this \#{ui_lookup(:table=>\"ems_container\")}"),
        },
      ]
    },
  ])
end
