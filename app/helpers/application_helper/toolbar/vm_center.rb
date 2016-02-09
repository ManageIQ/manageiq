class ApplicationHelper::Toolbar::VmCenter < ApplicationHelper::Toolbar::Basic
  button_group('vm_vmdb', [
    {
      :buttonSelect => "vm_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "vm_refresh",
          :icon         => "fa fa-refresh fa-lg",
          :text         => N_("Refresh Relationships and Power States"),
          :title        => N_("Refresh relationships and power states for all items related to this VM"),
          :confirm      => N_("Refresh relationships and power states for all items related to this VM?"),
        },
        {
          :button       => "vm_scan",
          :icon         => "fa fa-search fa-lg",
          :text         => N_("Perform SmartState Analysis"),
          :title        => N_("Perform SmartState Analysis on this VM"),
          :confirm      => N_("Perform SmartState Analysis on this VM?"),
        },
        {
          :button       => "vm_collect_running_processes",
          :icon         => "fa fa-eyedropper fa-lg",
          :text         => N_("Extract Running Processes"),
          :title        => N_("Extract Running Processes for this VM"),
          :confirm      => N_("Extract Running Processes for this VM?"),
        },
        {
          :separator    => nil,
        },
        {
          :button       => "vm_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit this VM"),
          :title        => N_("Edit this VM"),
          :url          => "/edit",
        },
        {
          :button       => "vm_ownership",
          :icon         => "pficon pficon-user fa-lg",
          :text         => N_("Set Ownership"),
          :title        => N_("Set Ownership for this VM"),
        },
        {
          :button       => "vm_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove from the VMDB"),
          :title        => N_("Remove this VM from the VMDB"),
          :url_parms    => "&refresh=y",
          :confirm      => N_("Warning: This VM and ALL of its components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this VM?"),
        },
        {
          :button       => "vm_evm_relationship",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Management Engine Relationship"),
          :title        => N_("Edit Management Engine Relationship"),
          :url          => "/evm_relationship",
        },
        {
          :separator    => nil,
        },
        {
          :button       => "vm_right_size",
          :icon         => "product product-custom-6 fa-lg",
          :text         => N_("Right-Size Recommendations"),
          :title        => N_("CPU/Memory Recommendations of this VM"),
        },
        {
          :button       => "vm_reconfigure",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Reconfigure this VM"),
          :title        => N_("Reconfigure the Memory/CPU of this VM"),
        },
      ]
    },
  ])
  button_group('vm_policy', [
    {
      :buttonSelect => "vm_policy_choice",
      :icon         => "fa fa-shield fa-lg",
      :title        => N_("Policy"),
      :text         => N_("Policy"),
      :items => [
        {
          :button       => "vm_protect",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Manage Policies"),
          :title        => N_("Manage Policies for this VM"),
        },
        {
          :button       => "vm_policy_sim",
          :icon         => "fa fa-play-circle-o fa-lg",
          :text         => N_("Policy Simulation"),
          :title        => N_("View Policy Simulation for this VM"),
        },
        {
          :button       => "vm_tag",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Tags"),
          :title        => N_("Edit Tags for this VM"),
        },
        {
          :button       => "vm_check_compliance",
          :icon         => "fa fa-search fa-lg",
          :text         => N_("Check Compliance of Last Known Configuration"),
          :title        => N_("Check Compliance of the last known configuration for this VM"),
          :confirm      => N_("Initiate Check Compliance of the last known configuration for this VM?"),
        },
      ]
    },
  ])
  button_group('vm_lifecycle', [
    {
      :buttonSelect => "vm_lifecycle_choice",
      :icon         => "fa fa-recycle fa-lg",
      :title        => N_("Lifecycle"),
      :text         => N_("Lifecycle"),
      :items => [
        {
          :button       => "vm_clone",
          :icon         => "product product-clone fa-lg",
          :text         => N_("Clone this VM"),
          :title        => N_("Clone this VM"),
        },
        {
          :button       => "vm_publish",
          :icon         => "pficon pficon-export",
          :text         => N_("Publish this VM to a Template"),
          :title        => N_("Publish this VM to a Template"),
        },
        {
          :button       => "vm_migrate",
          :icon         => "product product-migrate fa-lg",
          :text         => N_("Migrate this VM"),
          :title        => N_("Migrate this VM to another Host/Datastore"),
        },
        {
          :button       => "vm_retire",
          :icon         => "fa fa-clock-o fa-lg",
          :text         => N_("Set Retirement Date"),
          :title        => N_("Set Retirement Dates for this VM"),
        },
        {
          :button       => "vm_retire_now",
          :icon         => "fa fa-clock-o fa-lg",
          :text         => N_("Retire this VM"),
          :title        => N_("Retire this VM"),
          :confirm      => N_("Retire this VM?"),
        },
      ]
    },
  ])
  button_group('vm_monitoring', [
    {
      :buttonSelect => "vm_monitoring_choice",
      :icon         => "product product-monitoring fa-lg",
      :title        => N_("Monitoring"),
      :text         => N_("Monitoring"),
      :items => [
        {
          :button       => "vm_perf",
          :icon         => "product product-monitoring fa-lg",
          :text         => N_("Utilization"),
          :title        => N_("Show Capacity & Utilization data for this VM"),
          :url          => "/show",
          :url_parms    => "?display=performance",
        },
        {
          :button       => "vm_timeline",
          :icon         => "product product-timeline fa-lg",
          :text         => N_("Timelines"),
          :title        => N_("Show Timelines for this VM"),
          :url          => "/show",
          :url_parms    => "?display=timeline",
        },
      ]
    },
  ])
  button_group('vm_operations', [
    {
      :buttonSelect => "vm_power_choice",
      :icon         => "fa fa-power-off fa-lg",
      :title        => N_("VM Power Functions"),
      :text         => N_("Power"),
      :items => [
        {
          :button       => "vm_guest_shutdown",
          :image        => "guest_shutdown",
          :text         => N_("Shutdown Guest"),
          :title        => N_("Shutdown the Guest OS on this VM"),
          :confirm      => N_("Shutdown the Guest OS on this VM?"),
        },
        {
          :button       => "vm_guest_restart",
          :image        => "guest_restart",
          :text         => N_("Restart Guest"),
          :title        => N_("Restart the Guest OS on this VM"),
          :confirm      => N_("Restart the Guest OS on this VM?"),
        },
        {
          :separator    => nil,
        },
        {
          :button       => "vm_start",
          :image        => "power_on",
          :text         => N_("Power On"),
          :title        => N_("Power On this VM"),
          :confirm      => N_("Power On this VM?"),
        },
        {
          :button       => "vm_stop",
          :image        => "power_off",
          :text         => N_("Power Off"),
          :title        => N_("Power Off this VM"),
          :confirm      => N_("Power Off this VM?"),
        },
        {
          :button       => "vm_suspend",
          :image        => "power_suspend",
          :text         => N_("Suspend"),
          :title        => N_("Suspend this VM"),
          :confirm      => N_("Suspend this VM?"),
        },
        {
          :button       => "vm_reset",
          :image        => "power_reset",
          :text         => N_("Reset"),
          :title        => N_("Reset this VM"),
          :confirm      => N_("Reset this VM?"),
        },
      ]
    },
    {
      :button       => "vm_console",
      :icon         => "pficon pficon-screen fa-lg",
      :url          => "/console",
      :popup        => true,
      :title        => N_("Open a web-based console for this VM"),
      :confirm      => N_("Opening a VM web-based console can take a while and requires that the VMware MKS plugin version configured for Management Engine already be installed and working.  Are you sure?"),
    },
    {
      :button       => "vm_vnc_console",
      :icon         => "fa fa-html5 fa-lg",
      :url          => "html5_console",
      :title        => N_("Open a web-based VNC or SPICE console for this VM"),
      :confirm      => N_("Opening a web-based VM VNC or SPICE console requires that the Provider is pre-configured to allow VNC connections.  Are you sure?"),
    },
    {
      :button       => "vm_vmrc_console",
      :icon         => "pficon pficon-screen fa-lg",
      :url          => "/vmrc_console",
      :popup        => true,
      :title        => N_("Open a web-based VMRC console for this VM"),
      :confirm      => N_("Opening a VM web-based VMRC console requires that VMRC is pre-configured to work in your browser.  Are you sure?"),
    },
  ])
  button_group('snapshot_tasks', [
    {
      :button       => "vm_snapshot_add",
      :icon         => "pficon pficon-add-circle-o fa-lg",
      :title        => N_("Create a new snapshot for this VM"),
      :url          => "/snap",
      :onwhen       => "1",
    },
    {
      :buttonSelect => "vm_delete_snap_choice",
      :icon         => "pficon pficon-delete fa-lg",
      :title        => N_("Delete Snapshots"),
      :items => [
        {
          :button       => "vm_snapshot_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Delete Selected Snapshot"),
          :title        => N_("Delete Selected Snapshot"),
          :confirm      => N_("The selected snapshot will be permanently deleted. Are you sure you want to delete the selected snapshot?"),
          :url_parms    => "main_div",
          :onwhen       => "1",
        },
        {
          :button       => "vm_snapshot_delete_all",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Delete All Existing Snapshots"),
          :title        => N_("Delete All Existing Snapshots"),
          :confirm      => N_("Delete all of this VMs existing snapshots?"),
        },
      ]
    },
    {
      :button       => "vm_snapshot_revert",
      :icon         => "fa fa-undo fa-lg",
      :title        => N_("Revert to selected snapshot"),
      :confirm      => N_("This VM will revert to selected snapshot. Are you sure you want to revert to the selected snapshot?"),
      :onwhen       => "1",
    },
  ])
  button_group('vmtree_tasks', [
    {
      :button       => "vm_tag",
      :icon         => "pficon pficon-edit fa-lg",
      :title        => N_("Edit Tags for this VM"),
    },
    {
      :button       => "vm_compare",
      :icon         => "product product-compare fa-lg",
      :title        => N_("Compare selected VMs"),
      :url_parms    => "main_div",
      :enabled      => "false",
      :onwhen       => "2+",
    },
  ])
end
