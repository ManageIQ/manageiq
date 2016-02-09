class ApplicationHelper::Toolbar::HostCenter < ApplicationHelper::Toolbar::Basic
  button_group('host_vmdb', [
    {
      :buttonSelect => "host_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "host_refresh",
          :icon         => "fa fa-refresh fa-lg",
          :text         => N_("Refresh Relationships and Power States"),
          :title        => N_("Refresh relationships and power states for all items related to this item"),
          :confirm      => N_("Refresh relationships and power states for all items related to this item?"),
        },
        {
          :button       => "host_scan",
          :icon         => "fa fa-search fa-lg",
          :text         => N_("Perform SmartState Analysis"),
          :title        => N_("Perform SmartState Analysis on this item"),
          :confirm      => N_("Perform SmartState Analysis on this item?"),
        },
        {
          :separator    => nil,
        },
        {
          :button       => "host_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit this item"),
          :title        => N_("Edit this item"),
          :url          => "/edit",
        },
        {
          :button       => "host_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove from the VMDB"),
          :title        => N_("Remove this item from the VMDB"),
          :url_parms    => "&refresh=y",
          :confirm      => N_("Warning: This item and ALL of its components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this item?"),
        },
      ]
    },
  ])
  button_group('host_policy', [
    {
      :buttonSelect => "host_policy_choice",
      :icon         => "fa fa-shield fa-lg",
      :title        => N_("Policy"),
      :text         => N_("Policy"),
      :items => [
        {
          :button       => "host_protect",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Manage Policies"),
          :title        => N_("Manage Policies for this item"),
        },
        {
          :button       => "host_tag",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Tags"),
          :title        => N_("Edit Tags for this item"),
        },
        {
          :button       => "host_check_compliance",
          :icon         => "fa fa-search fa-lg",
          :text         => N_("Check Compliance of Last Known Configuration"),
          :title        => N_("Check Compliance of the last known configuration for this item"),
          :confirm      => N_("Initiate Check Compliance of the last known configuration for this item?"),
        },
        {
          :button       => "host_analyze_check_compliance",
          :icon         => "fa fa-search fa-lg",
          :text         => N_("Analyze then Check Compliance"),
          :title        => N_("Analyze then Check Compliance for this item"),
          :confirm      => N_("Analyze then Check Compliance for this item?"),
        },
      ]
    },
  ])
  button_group('host_lifecycle', [
    {
      :buttonSelect => "host_lifecycle_choice",
      :icon         => "fa fa-recycle fa-lg",
      :title        => N_("Lifecycle"),
      :text         => N_("Lifecycle"),
      :items => [
        {
          :button       => "host_miq_request_new",
          :icon         => "pficon pficon-add-circle-o fa-lg",
          :text         => N_("Provision this item"),
          :title        => N_("Provision this item"),
        },
      ]
    },
  ])
  button_group('host_monitoring', [
    {
      :buttonSelect => "host_monitoring_choice",
      :icon         => "product product-monitoring fa-lg",
      :title        => N_("Monitoring"),
      :text         => N_("Monitoring"),
      :items => [
        {
          :button       => "host_perf",
          :icon         => "product product-monitoring fa-lg",
          :text         => N_("Utilization"),
          :title        => N_("Show Capacity & Utilization data for this item"),
          :url          => "/show",
          :url_parms    => "?display=performance",
        },
        {
          :button       => "host_timeline",
          :icon         => "product product-timeline fa-lg",
          :text         => N_("Timelines"),
          :title        => N_("Show Timelines for this item"),
          :url          => "/show",
          :url_parms    => "?display=timeline",
        },
      ]
    },
  ])
  button_group('host_operations', [
    {
      :buttonSelect => "host_power_choice",
      :icon         => "fa fa-power-off fa-lg",
      :title        => N_("Power Functions"),
      :text         => N_("Power"),
      :items => [
        {
          :button       => "host_enter_maint_mode",
          :image        => "enter_maint_mode",
          :text         => N_("Enter Maintenance Mode"),
          :title        => N_("Put this item into Maintenance Mode"),
          :confirm      => N_("Put this item into Maintenance Mode?"),
        },
        {
          :button       => "host_exit_maint_mode",
          :image        => "exit_maint_mode",
          :text         => N_("Exit Maintenance Mode"),
          :title        => N_("Take this item out of Maintenance Mode"),
          :confirm      => N_("Take this item out of Maintenance Mode?"),
        },
        {
          :button       => "host_standby",
          :image        => "standby",
          :text         => N_("Enter Standby Mode"),
          :title        => N_("Shutdown this item to Standby Mode"),
          :confirm      => N_("Shutdown this item to Standby Mode?"),
        },
        {
          :button       => "host_shutdown",
          :image        => "guest_shutdown",
          :text         => N_("Shutdown"),
          :title        => N_("Shutdown this item"),
          :confirm      => N_("Shutdown this item?"),
        },
        {
          :button       => "host_reboot",
          :image        => "guest_restart",
          :text         => N_("Restart"),
          :title        => N_("Restart this item"),
          :confirm      => N_("Restart this item?"),
        },
        {
          :separator    => nil,
        },
        {
          :button       => "host_start",
          :image        => "power_on",
          :text         => N_("Power On"),
          :title        => N_("Power On this item"),
          :confirm      => N_("Power On this item?"),
        },
        {
          :button       => "host_stop",
          :image        => "power_off",
          :text         => N_("Power Off"),
          :title        => N_("Power Off this item"),
          :confirm      => N_("Power Off this item?"),
        },
        {
          :button       => "host_reset",
          :image        => "power_reset",
          :text         => N_("Reset"),
          :title        => N_("Reset this item"),
          :confirm      => N_("Reset this item?"),
        },
      ]
    },
  ])
end
