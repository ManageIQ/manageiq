class ApplicationHelper::Toolbar::XVmCloudCenter < ApplicationHelper::Toolbar::Basic
  button_group('instance_vmdb', [
    select(
      :instance_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :instance_refresh,
          'fa fa-refresh fa-lg',
          N_('Refresh relationships and power states for all items related to this Instance'),
          N_('Refresh Relationships and Power States'),
          :confirm => N_("Refresh relationships and power states for all items related to this Instance?")),
        button(
          :instance_scan,
          'fa fa-search fa-lg',
          N_('Perform SmartState Analysis on this Instance'),
          N_('Perform SmartState Analysis'),
          :confirm => N_("Perform SmartState Analysis on this Instance?")),
        separator,
        button(
          :instance_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit this Instance'),
          t),
        button(
          :instance_ownership,
          'pficon pficon-user fa-lg',
          N_('Set Ownership for this Instance'),
          N_('Set Ownership')),
        button(
          :instance_delete,
          'pficon pficon-delete fa-lg',
          N_('Remove this Instance from the VMDB'),
          N_('Remove from the VMDB'),
          :url_parms => "&refresh=y",
          :confirm   => N_("Warning: This Instance and ALL of its components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this Instance?")),
        button(
          :instance_evm_relationship,
          'pficon pficon-edit fa-lg',
          t = N_('Edit Management Engine Relationship'),
          t),
        separator,
        button(
          :instance_resize,
          'pficon pficon-edit fa-lg',
          t = N_('Reconfigure this Instance'),
          t)
      ]
    ),
  ])
  button_group('instance_policy', [
    select(
      :instance_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :items => [
        button(
          :instance_protect,
          'pficon pficon-edit fa-lg',
          N_('Manage Policies for this Instance'),
          N_('Manage Policies')),
        button(
          :instance_policy_sim,
          'fa fa-play-circle-o fa-lg',
          N_('View Policy Simulation for this Instance'),
          N_('Policy Simulation')),
        button(
          :instance_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for this Instance'),
          N_('Edit Tags')),
        button(
          :instance_check_compliance,
          'fa fa-search fa-lg',
          N_('Check Compliance of the last known configuration for this Instance'),
          N_('Check Compliance of Last Known Configuration'),
          :confirm => N_("Initiate Check Compliance of the last known configuration for this Instance?")),
      ]
    ),
  ])
  button_group('instance_lifecycle', [
    select(
      :instance_lifecycle_choice,
      'fa fa-recycle fa-lg',
      t = N_('Lifecycle'),
      t,
      :items => [
        button(
          :instance_retire,
          'fa fa-clock-o fa-lg',
          N_('Set Retirement Dates for this Instance'),
          N_('Set Retirement Date')),
        button(
          :instance_retire_now,
          'fa fa-clock-o fa-lg',
          t = N_('Retire this Instance'),
          t,
          :confirm => N_("Retire this Instance?")),
        button(
          :instance_live_migrate,
          'product product-migrate fa-lg',
          t = N_('Migrate Instance'),
          t,
          :klass     => ApplicationHelper::Button::InstanceMigrate,
          :url_parms => 'main_div')
      ]
    ),
  ])
  button_group('instance_monitoring', [
    select(
      :instance_monitoring_choice,
      'product product-monitoring fa-lg',
      t = N_('Monitoring'),
      t,
      :items => [
        button(
          :instance_perf,
          'product product-monitoring fa-lg',
          N_('Show Capacity & Utilization data for this Instance'),
          N_('Utilization'),
          :url_parms => "?display=performance"),
        button(
          :instance_timeline,
          'product product-timeline fa-lg',
          N_('Show Timelines for this Instance'),
          N_('Timelines'),
          :klass     => ApplicationHelper::Button::InstanceTimeline,
          :url_parms => "?display=timeline"),
      ]
    ),
  ])
  button_group('instance_operations', [
    select(
      :instance_power_choice,
      'fa fa-power-off fa-lg',
      N_('Instance Power Functions'),
      N_('Power'),
      :items => [
        button(
          :instance_stop,
          nil,
          N_('Stop this Instance'),
          N_('Stop'),
          :image   => "guest_shutdown",
          :confirm => N_("Stop this Instance?")),
        button(
          :instance_start,
          nil,
          N_('Start this Instance'),
          N_('Start'),
          :image   => "power_on",
          :confirm => N_("Start this Instance?")),
        button(
          :instance_pause,
          nil,
          N_('Pause this Instance'),
          N_('Pause'),
          :image   => "power_pause",
          :confirm => N_("Pause this Instance?")),
        button(
          :instance_suspend,
          nil,
          N_('Suspend this Instance'),
          N_('Suspend'),
          :image   => "suspend",
          :confirm => N_("Suspend this Instance?")),
        button(
          :instance_shelve,
          nil,
          N_('Shelve this Instance'),
          N_('Shelve'),
          :image   => "power_shelve",
          :confirm => N_("Shelve this Instance?")),
        button(
          :instance_shelve_offload,
          nil,
          N_('Shelve Offload this Instance'),
          N_('Shelve Offload'),
          :image   => "power_shelve_offload",
          :confirm => N_("Shelve Offload this Instance?")),
        button(
          :instance_resume,
          nil,
          N_('Resume this Instance'),
          N_('Resume'),
          :image   => "power_resume",
          :confirm => N_("Resume this Instance?")),
        separator,
        button(
          :instance_guest_restart,
          nil,
          N_('Soft Reboot this Instance'),
          N_('Soft Reboot'),
          :image   => "power_reset",
          :confirm => N_("Soft Reboot this Instance?")),
        button(
          :instance_reset,
          nil,
          N_('Hard Reboot the Guest OS on this Instance'),
          N_('Hard Reboot'),
          :image   => "guest_restart",
          :confirm => N_("Hard Reboot the Guest OS on this Instance?")),
        button(
          :instance_terminate,
          nil,
          N_('Terminate this Instance'),
          N_('Terminate'),
          :image   => "power_off",
          :confirm => N_("Terminate this Instance?")),
      ]
    ),
    button(
      :vm_vnc_console,
      'fa fa-html5 fa-lg',
      N_('Open a web-based VNC or SPICE console for this VM'),
      nil,
      :url     => "html5_console",
      :confirm => N_("Opening a web-based VM VNC or SPICE console requires that the Provider is pre-configured to allow VNC connections.  Are you sure?")),
  ])
end
