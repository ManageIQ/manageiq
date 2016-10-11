class ApplicationHelper::Toolbar::XVmCenter < ApplicationHelper::Toolbar::Basic
  button_group('vm_vmdb', [
    select(
      :vm_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :vm_refresh,
          'fa fa-refresh fa-lg',
          N_('Refresh relationships and power states for all items related to this VM'),
          N_('Refresh Relationships and Power States'),
          :confirm => N_("Refresh relationships and power states for all items related to this VM?"),
          :klass   => ApplicationHelper::Button::VmRefresh),
        button(
          :vm_scan,
          'fa fa-search fa-lg',
          N_('Perform SmartState Analysis on this VM'),
          N_('Perform SmartState Analysis'),
          :confirm => N_("Perform SmartState Analysis on this VM?"),
          :klass   => ApplicationHelper::Button::VmInstanceTemplateScan),
        button(
          :vm_collect_running_processes,
          'fa fa-eyedropper fa-lg',
          N_('Extract Running Processes for this VM'),
          N_('Extract Running Processes'),
          :confirm => N_("Extract Running Processes for this VM?"),
          :klass => ApplicationHelper::Button::GenericFeatureButtonWithDisable,
          :options => {:feature => :collect_running_processes}),
        separator,
        button(
          :vm_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit this VM'),
          t),
        button(
          :vm_ownership,
          'pficon pficon-user fa-lg',
          N_('Set Ownership for this VM'),
          N_('Set Ownership')),
        button(
          :vm_delete,
          'pficon pficon-delete fa-lg',
          N_('Remove this Virtual machine'),
          N_('Remove Virtual Machine'),
          :url_parms => "&refresh=y",
          :confirm   => N_("Warning: This Virtual Machine and ALL of its components will be permanently removed!")),
        button(
          :vm_evm_relationship,
          'pficon pficon-edit fa-lg',
          t = N_('Edit Management Engine Relationship'),
          t),
        separator,
        button(
          :vm_right_size,
          'product product-custom-6 fa-lg',
          N_('CPU/Memory Recommendations of this VM'),
          N_('Right-Size Recommendations')),
        button(
          :vm_reconfigure,
          'pficon pficon-edit fa-lg',
          N_('Reconfigure the Memory/CPU of this VM'),
          N_('Reconfigure this VM'),
          :klass => ApplicationHelper::Button::VmReconfigure),
      ]
    ),
  ])
  button_group('vm_policy', [
    select(
      :vm_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :items => [
        button(
          :vm_protect,
          'pficon pficon-edit fa-lg',
          N_('Manage Policies for this VM'),
          N_('Manage Policies'),
          :klass => ApplicationHelper::Button::VmTemplatePolicy),
        button(
          :vm_policy_sim,
          'fa fa-play-circle-o fa-lg',
          N_('View Policy Simulation for this VM'),
          N_('Policy Simulation'),
          :klass => ApplicationHelper::Button::VmTemplatePolicy),
        button(
          :vm_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for this VM'),
          N_('Edit Tags')),
        button(
          :vm_check_compliance,
          'fa fa-search fa-lg',
          N_('Check Compliance of the last known configuration for this VM'),
          N_('Check Compliance of Last Known Configuration'),
          :confirm => N_("Initiate Check Compliance of the last known configuration for this VM?")),
      ]
    ),
  ])
  button_group('vm_lifecycle', [
    select(
      :vm_lifecycle_choice,
      'fa fa-recycle fa-lg',
      t = N_('Lifecycle'),
      t,
      :items => [
        button(
          :vm_clone,
          'product product-clone fa-lg',
          t = N_('Clone this VM'),
          t,
          :klass   => ApplicationHelper::Button::GenericFeatureButton,
          :options => {:feature => :clone}),
        button(
          :vm_publish,
          'pficon pficon-export',
          t = N_('Publish this VM to a Template'),
          t,
          :klass => ApplicationHelper::Button::VmPublish),
        button(
          :vm_migrate,
          'product product-migrate fa-lg',
          N_('Migrate this VM to another Host/Datastore'),
          N_('Migrate this VM'),
          :klass => ApplicationHelper::Button::GenericFeatureButton,
          :options => {:feature => :migrate}),
        button(
          :vm_retire,
          'fa fa-clock-o fa-lg',
          N_('Set Retirement Dates for this VM'),
          N_('Set Retirement Date'),
          :klass => ApplicationHelper::Button::VmRetire),
        button(
          :vm_retire_now,
          'fa fa-clock-o fa-lg',
          t = N_('Retire this VM'),
          t,
          :confirm => N_("Retire this VM?"),
          :klass => ApplicationHelper::Button::VmRetireNow),
      ]
    ),
  ])
  button_group('vm_monitoring', [
    select(
      :vm_monitoring_choice,
      'product product-monitoring fa-lg',
      t = N_('Monitoring'),
      t,
      :items => [
        button(
          :vm_perf,
          'product product-monitoring fa-lg',
          N_('Show Capacity & Utilization data for this VM'),
          N_('Utilization'),
          :url_parms => "?display=performance"),
        button(
          :vm_timeline,
          'product product-timeline fa-lg',
          N_('Show Timelines for this VM'),
          N_('Timelines'),
          :url_parms => "?display=timeline"),
      ]
    ),
  ])
  button_group('vm_operations', [
    select(
      :vm_power_choice,
      'fa fa-power-off fa-lg',
      N_('VM Power Functions'),
      N_('Power'),
      :items => [
        button(
          :vm_guest_shutdown,
          nil,
          N_('Shutdown the Guest OS on this VM'),
          N_('Shutdown Guest'),
          :image   => "guest_shutdown",
          :confirm => N_("Shutdown the Guest OS on this VM?"),
          :klass   => ApplicationHelper::Button::GenericFeatureButtonWithDisable,
          :options => {:feature => :shutdown_guest}),
        button(
          :vm_guest_restart,
          nil,
          N_('Restart the Guest OS on this VM'),
          N_('Restart Guest'),
          :image   => "guest_restart",
          :confirm => N_("Restart the Guest OS on this VM?"),
          :klass   => ApplicationHelper::Button::GenericFeatureButtonWithDisable,
          :options => {:feature => :reboot_guest}),
        separator,
        button(
          :vm_start,
          nil,
          N_('Power On this VM'),
          N_('Power On'),
          :image   => "power_on",
          :confirm => N_("Power On this VM?"),
          :klass   => ApplicationHelper::Button::GenericFeatureButtonWithDisable,
          :options => {:feature => :start}),
        button(
          :vm_stop,
          nil,
          N_('Power Off this VM'),
          N_('Power Off'),
          :image   => "power_off",
          :confirm => N_("Power Off this VM?"),
          :klass   => ApplicationHelper::Button::GenericFeatureButtonWithDisable,
          :options => {:feature => :stop}),
        button(
          :vm_suspend,
          nil,
          N_('Suspend this VM'),
          N_('Suspend'),
          :image   => "power_suspend",
          :confirm => N_("Suspend this VM?"),
          :klass   => ApplicationHelper::Button::GenericFeatureButtonWithDisable,
          :options => {:feature => :suspend}),
        button(
          :vm_reset,
          nil,
          N_('Reset this VM'),
          N_('Reset'),
          :image   => "power_reset",
          :confirm => N_("Reset this VM?"),
          :klass   => ApplicationHelper::Button::GenericFeatureButtonWithDisable,
          :options => {:feature => :reset}),
      ]
    ),
    button(
      :vm_console,
      'pficon pficon-screen fa-lg',
      N_('Open a web-based console for this VM'),
      nil,
      :url     => "console",
      :confirm => N_("Opening a VM web-based console can take a while and requires that the VMware MKS plugin version configured for Management Engine already be installed and working.  Are you sure?")),
    button(
      :vm_vnc_console,
      'fa fa-html5 fa-lg',
      N_('Open a web-based VNC or SPICE console for this VM'),
      nil,
      :url     => "html5_console",
      :confirm => N_("Opening a web-based VM VNC or SPICE console requires that the Provider is pre-configured to allow VNC connections.  Are you sure?")),
    button(
      :vm_vmrc_console,
      'pficon pficon-screen fa-lg',
      N_('Open a web-based VMRC console for this VM.  This requires that VMRC is pre-configured to work in your browser.'),
      nil,
      :url     => "vmrc_console",
      :confirm => N_("Opening a VM web-based VMRC console requires that VMRC is pre-configured to work in your browser.  Are you sure?")),
    button(
      :cockpit_console,
      nil,
      N_('Open a new browser window with Cockpit for this VM.  This requires that Cockpit is pre-configured on the VM.'),
      nil,
      :image   => "cockpit",
      :url     => "launch_cockpit"),
  ])
  button_group('snapshot_tasks', [
    button(
      :vm_snapshot_add,
      'pficon pficon-add-circle-o fa-lg',
      N_('Create a new snapshot for this VM'),
      nil,
      :onwhen => "1"),
    select(
      :vm_delete_snap_choice,
      'pficon pficon-delete fa-lg',
      N_('Delete Snapshots'),
      nil,
      :items => [
        button(
          :vm_snapshot_delete,
          'pficon pficon-delete fa-lg',
          t = N_('Delete Selected Snapshot'),
          t,
          :confirm   => N_("The selected snapshot will be permanently deleted. Are you sure you want to delete the selected snapshot?"),
          :url_parms => "main_div",
          :onwhen    => "1"),
        button(
          :vm_snapshot_delete_all,
          'pficon pficon-delete fa-lg',
          t = N_('Delete All Existing Snapshots'),
          t,
          :confirm => N_("Delete all of this VMs existing snapshots?")),
      ]
    ),
    button(
      :vm_snapshot_revert,
      'fa fa-undo fa-lg',
      N_('Revert to selected snapshot'),
      nil,
      :confirm => N_("This VM will revert to selected snapshot. Are you sure you want to revert to the selected snapshot?"),
      :onwhen  => "1",
      :klass   => ApplicationHelper::Button::VmSnapshotRevert),
  ])
  button_group('vmtree_tasks', [
    button(
      :vm_tag,
      'pficon pficon-edit fa-lg',
      N_('Edit Tags for this VM'),
      nil),
    button(
      :vm_compare,
      'product product-compare fa-lg',
      N_('Compare selected VMs'),
      nil,
      :url_parms => "main_div",
      :enabled   => false,
      :onwhen    => "2+"),
  ])
end
