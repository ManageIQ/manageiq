class ApplicationHelper::Toolbar::EmsCloudCenter < ApplicationHelper::Toolbar::Basic
  button_group('ems_cloud_vmdb', [
    {
      :buttonSelect => "ems_cloud_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "ems_cloud_refresh",
          :icon         => "fa fa-refresh fa-lg",
          :text         => N_("Refresh Relationships and Power States"),
          :title        => N_("Refresh relationships and power states for all items related to this \#{ui_lookup(:table=>\"ems_cloud\")}"),
          :confirm      => N_("Refresh relationships and power states for all items related to this \#{ui_lookup(:table=>\"ems_cloud\")}?"),
        },
        {
          :separator    => nil,
        },
        {
          :button       => "ems_cloud_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit this \#{ui_lookup(:table=>\"ems_cloud\")}"),
          :title        => N_("Edit this \#{ui_lookup(:table=>\"ems_cloud\")}"),
          :full_path    => "<%= edit_ems_cloud_path(@ems) %>",
        },
        {
          :button       => "ems_cloud_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove this \#{ui_lookup(:table=>\"ems_cloud\")} from the VMDB"),
          :title        => N_("Remove this \#{ui_lookup(:table=>\"ems_cloud\")} from the VMDB"),
          :url_parms    => "&refresh=y",
          :confirm      => N_("Warning: This \#{ui_lookup(:table=>\"ems_cloud\")} and ALL of its components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this \#{ui_lookup(:table=>\"ems_cloud\")}?"),
        },
      ]
    },
  ])
  button_group('ems_cloud_policy', [
    {
      :buttonSelect => "ems_cloud_policy_choice",
      :icon         => "fa fa-shield fa-lg",
      :title        => N_("Policy"),
      :text         => N_("Policy"),
      :items => [
        {
          :button       => "ems_cloud_protect",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Manage Policies"),
          :title        => N_("Manage Policies for this \#{ui_lookup(:table=>\"ems_cloud\")}"),
        },
        {
          :button       => "ems_cloud_tag",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Tags"),
          :title        => N_("Edit Tags for this \#{ui_lookup(:table=>\"ems_cloud\")}"),
        },
      ]
    },
  ])
  button_group('ems_cloud_monitoring', [
    {
      :buttonSelect => "ems_cloud_monitoring_choice",
      :icon         => "product product-monitoring fa-lg",
      :title        => N_("Monitoring"),
      :text         => N_("Monitoring"),
      :items => [
        {
          :button       => "ems_cloud_timeline",
          :icon         => "product product-timeline fa-lg",
          :text         => N_("Timelines"),
          :title        => N_("Show Timelines for this \#{ui_lookup(:table=>\"ems_cloud\")}"),
          :url_parms    => "?display=timeline",
        },
      ]
    },
  ])
end
