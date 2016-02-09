class ApplicationHelper::Toolbar::XVmCloudCenter < ApplicationHelper::Toolbar::Basic
  button_group('instance_vmdb', [
    {
      :buttonSelect => "instance_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "instance_refresh",
          :icon         => "fa fa-refresh fa-lg",
          :text         => N_("Refresh Relationships and Power States"),
          :title        => N_("Refresh relationships and power states for all items related to this Instance"),
          :confirm      => N_("Refresh relationships and power states for all items related to this Instance?"),
        },
        {
          :button       => "instance_scan",
          :icon         => "fa fa-search fa-lg",
          :text         => N_("Perform SmartState Analysis"),
          :title        => N_("Perform SmartState Analysis on this Instance"),
          :confirm      => N_("Perform SmartState Analysis on this Instance?"),
        },
        {
          :separator    => nil,
        },
        {
          :button       => "instance_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit this Instance"),
          :title        => N_("Edit this Instance"),
        },
        {
          :button       => "instance_ownership",
          :icon         => "pficon pficon-user fa-lg",
          :text         => N_("Set Ownership"),
          :title        => N_("Set Ownership for this Instance"),
        },
        {
          :button       => "instance_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove from the VMDB"),
          :title        => N_("Remove this Instance from the VMDB"),
          :url_parms    => "&refresh=y",
          :confirm      => N_("Warning: This Instance and ALL of its components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this Instance?"),
        },
        {
          :button       => "instance_evm_relationship",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Management Engine Relationship"),
          :title        => N_("Edit Management Engine Relationship"),
        },
        {
          :separator    => nil,
        },
      ]
    },
  ])
  button_group('instance_policy', [
    {
      :buttonSelect => "instance_policy_choice",
      :icon         => "fa fa-shield fa-lg",
      :title        => N_("Policy"),
      :text         => N_("Policy"),
      :items => [
        {
          :button       => "instance_protect",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Manage Policies"),
          :title        => N_("Manage Policies for this Instance"),
        },
        {
          :button       => "instance_policy_sim",
          :icon         => "fa fa-play-circle-o fa-lg",
          :text         => N_("Policy Simulation"),
          :title        => N_("View Policy Simulation for this Instance"),
        },
        {
          :button       => "instance_tag",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Tags"),
          :title        => N_("Edit Tags for this Instance"),
        },
        {
          :button       => "instance_check_compliance",
          :icon         => "fa fa-search fa-lg",
          :text         => N_("Check Compliance of Last Known Configuration"),
          :title        => N_("Check Compliance of the last known configuration for this Instance"),
          :confirm      => N_("Initiate Check Compliance of the last known configuration for this Instance?"),
        },
      ]
    },
  ])
  button_group('instance_lifecycle', [
    {
      :buttonSelect => "instance_lifecycle_choice",
      :icon         => "fa fa-recycle fa-lg",
      :title        => N_("Lifecycle"),
      :text         => N_("Lifecycle"),
      :items => [
        {
          :button       => "instance_retire",
          :icon         => "fa fa-clock-o fa-lg",
          :text         => N_("Set Retirement Date"),
          :title        => N_("Set Retirement Dates for this Instance"),
        },
        {
          :button       => "instance_retire_now",
          :icon         => "fa fa-clock-o fa-lg",
          :text         => N_("Retire this Instance"),
          :title        => N_("Retire this Instance"),
          :confirm      => N_("Retire this Instance?"),
        },
      ]
    },
  ])
  button_group('instance_monitoring', [
    {
      :buttonSelect => "instance_monitoring_choice",
      :icon         => "product product-monitoring fa-lg",
      :title        => N_("Monitoring"),
      :text         => N_("Monitoring"),
      :items => [
        {
          :button       => "instance_perf",
          :icon         => "product product-monitoring fa-lg",
          :text         => N_("Utilization"),
          :title        => N_("Show Capacity & Utilization data for this Instance"),
          :url_parms    => "?display=performance",
        },
        {
          :button       => "instance_timeline",
          :icon         => "product product-timeline fa-lg",
          :text         => N_("Timelines"),
          :title        => N_("Show Timelines for this Instance"),
          :url_parms    => "?display=timeline",
        },
      ]
    },
  ])
  button_group('instance_operations', [
    {
      :buttonSelect => "instance_power_choice",
      :icon         => "fa fa-power-off fa-lg",
      :title        => N_("Instance Power Functions"),
      :text         => N_("Power"),
      :items => [
        {
          :button       => "instance_stop",
          :image        => "guest_shutdown",
          :text         => N_("Stop"),
          :title        => N_("Stop this Instance"),
          :confirm      => N_("Stop this Instance?"),
        },
        {
          :button       => "instance_start",
          :image        => "power_on",
          :text         => N_("Start"),
          :title        => N_("Start this Instance"),
          :confirm      => N_("Start this Instance?"),
        },
        {
          :button       => "instance_pause",
          :image        => "power_pause",
          :text         => N_("Pause"),
          :title        => N_("Pause this Instance"),
          :confirm      => N_("Pause this Instance?"),
        },
        {
          :button       => "instance_suspend",
          :image        => "suspend",
          :text         => N_("Suspend"),
          :title        => N_("Suspend this Instance"),
          :confirm      => N_("Suspend this Instance?"),
        },
        {
          :button       => "instance_shelve",
          :image        => "power_shelve",
          :text         => N_("Shelve"),
          :title        => N_("Shelve this Instance"),
          :confirm      => N_("Shelve this Instance?"),
        },
        {
          :button       => "instance_shelve_offload",
          :image        => "power_shelve_offload",
          :text         => N_("Shelve Offload"),
          :title        => N_("Shelve Offload this Instance"),
          :confirm      => N_("Shelve Offload this Instance?"),
        },
        {
          :button       => "instance_resume",
          :image        => "power_resume",
          :text         => N_("Resume"),
          :title        => N_("Resume this Instance"),
          :confirm      => N_("Resume this Instance?"),
        },
        {
          :separator    => nil,
        },
        {
          :button       => "instance_guest_restart",
          :image        => "power_reset",
          :text         => N_("Soft Reboot"),
          :title        => N_("Soft Reboot this Instance"),
          :confirm      => N_("Soft Reboot this Instance?"),
        },
        {
          :button       => "instance_reset",
          :image        => "guest_restart",
          :text         => N_("Hard Reboot"),
          :title        => N_("Hard Reboot the Guest OS on this Instance"),
          :confirm      => N_("Hard Reboot the Guest OS on this Instance?"),
        },
        {
          :button       => "instance_terminate",
          :image        => "power_off",
          :text         => N_("Terminate"),
          :title        => N_("Terminate this Instance"),
          :confirm      => N_("Terminate this Instance?"),
        },
      ]
    },
    {
      :button       => "vm_vnc_console",
      :icon         => "fa fa-html5 fa-lg",
      :url          => "html5_console",
      :title        => N_("Open a web-based VNC or SPICE console for this VM"),
      :confirm      => N_("Opening a web-based VM VNC or SPICE console requires that the Provider is pre-configured to allow VNC connections.  Are you sure?"),
    },
  ])
end
