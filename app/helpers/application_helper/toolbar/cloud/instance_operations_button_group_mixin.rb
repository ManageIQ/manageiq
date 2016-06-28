module ApplicationHelper::Toolbar::Cloud::InstanceOperationsButtonGroupMixin
  def self.included(included_class)
    included_class.button_group('instance_operations', [
      included_class.select(
        :instance_power_choice,
        'fa fa-power-off fa-lg',
        N_('Instance Power Functions'),
        N_('Power'),
        :items => [
          included_class.button(
            :instance_stop,
            nil,
            N_('Stop this Instance'),
            N_('Stop'),
            :image   => "guest_shutdown",
            :confirm => N_("Stop this Instance?")),
          included_class.button(
            :instance_start,
            nil,
            N_('Start this Instance'),
            N_('Start'),
            :image   => "power_on",
            :confirm => N_("Start this Instance?")),
          included_class.button(
            :instance_pause,
            nil,
            N_('Pause this Instance'),
            N_('Pause'),
            :image   => "power_pause",
            :confirm => N_("Pause this Instance?")),
          included_class.button(
            :instance_suspend,
            nil,
            N_('Suspend this Instance'),
            N_('Suspend'),
            :image   => "suspend",
            :confirm => N_("Suspend this Instance?")),
          included_class.button(
            :instance_shelve,
            nil,
            N_('Shelve this Instance'),
            N_('Shelve'),
            :image   => "power_shelve",
            :confirm => N_("Shelve this Instance?")),
          included_class.button(
            :instance_shelve_offload,
            nil,
            N_('Shelve Offload this Instance'),
            N_('Shelve Offload'),
            :image   => "power_shelve_offload",
            :confirm => N_("Shelve Offload this Instance?")),
          included_class.button(
            :instance_resume,
            nil,
            N_('Resume this Instance'),
            N_('Resume'),
            :image   => "power_resume",
            :confirm => N_("Resume this Instance?")),
          included_class.separator,
          included_class.button(
            :instance_guest_restart,
            nil,
            N_('Soft Reboot this Instance'),
            N_('Soft Reboot'),
            :image   => "power_reset",
            :confirm => N_("Soft Reboot this Instance?")),
          included_class.button(
            :instance_reset,
            nil,
            N_('Hard Reboot the Guest OS on this Instance'),
            N_('Hard Reboot'),
            :image   => "guest_restart",
            :confirm => N_("Hard Reboot the Guest OS on this Instance?")),
          included_class.button(
            :instance_terminate,
            nil,
            N_('Delete this Instance'),
            N_('Delete'),
            :image   => "power_off",
            :confirm => N_("Delete this Instance?")),
        ]
      ),
      included_class.button(
        :vm_vnc_console,
        'fa fa-html5 fa-lg',
        N_('Open a web-based VNC or SPICE console for this VM'),
        nil,
        :url     => "html5_console",
        :confirm => N_("Opening a web-based VM VNC or SPICE console requires that the Provider is pre-configured to allow VNC connections.  Are you sure?")),
    ])
  end
end
