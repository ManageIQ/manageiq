class ApplicationHelper::Toolbar::EmsInfraCenter < ApplicationHelper::Toolbar::Basic
  button_group('ems_infra_vmdb', [
    {
      :buttonSelect => "ems_infra_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "ems_infra_refresh",
          :icon         => "fa fa-refresh fa-lg",
          :text         => N_("Refresh Relationships and Power States"),
          :title        => N_("Refresh relationships and power states for all items related to this \#{ui_lookup(:table=>\"ems_infra\")}"),
          :confirm      => N_("Refresh relationships and power states for all items related to this \#{ui_lookup(:table=>\"ems_infra\")}?"),
        },
        {
          :separator    => nil,
        },
        {
          :button       => "ems_infra_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit this \#{ui_lookup(:table=>\"ems_infra\")}"),
          :title        => N_("Edit this \#{ui_lookup(:table=>\"ems_infra\")}"),
          :url          => "/edit",
        },
        {
          :button       => "ems_infra_scale",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Scale this \#{ui_lookup(:table=>\"ems_infra\")}"),
          :title        => N_("Scale this \#{ui_lookup(:table=>\"ems_infra\")}"),
          :url          => "/scaling",
        },
        {
          :button       => "ems_infra_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove this \#{ui_lookup(:table=>\"ems_infra\")} from the VMDB"),
          :title        => N_("Remove this \#{ui_lookup(:table=>\"ems_infra\")} from the VMDB"),
          :url_parms    => "&refresh=y",
          :confirm      => N_("Warning: This \#{ui_lookup(:table=>\"ems_infra\")} and ALL of its components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this \#{ui_lookup(:table=>\"ems_infra\")}?"),
        },
      ]
    },
  ])
  button_group('ems_infra_policy', [
    {
      :buttonSelect => "ems_infra_policy_choice",
      :icon         => "fa fa-shield fa-lg",
      :title        => N_("Policy"),
      :text         => N_("Policy"),
      :items => [
        {
          :button       => "ems_infra_protect",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Manage Policies"),
          :title        => N_("Manage Policies for this \#{ui_lookup(:table=>\"ems_infra\")}"),
        },
        {
          :button       => "ems_infra_tag",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Tags"),
          :title        => N_("Edit Tags for this \#{ui_lookup(:table=>\"ems_infra\")}"),
        },
      ]
    },
  ])
  button_group('ems_infra_monitoring', [
    {
      :buttonSelect => "ems_infra_monitoring_choice",
      :icon         => "product product-monitoring fa-lg",
      :title        => N_("Monitoring"),
      :text         => N_("Monitoring"),
      :items => [
        {
          :button       => "ems_infra_timeline",
          :icon         => "product product-timeline fa-lg",
          :text         => N_("Timelines"),
          :title        => N_("Show Timelines for this \#{ui_lookup(:table=>\"ems_infra\")}"),
          :url          => "/show",
          :url_parms    => "?display=timeline",
        },
      ]
    },
  ])
end
