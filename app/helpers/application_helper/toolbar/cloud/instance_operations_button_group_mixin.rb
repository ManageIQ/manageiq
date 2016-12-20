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
            :confirm => N_("Stop this Instance?"),
            :klass   => ApplicationHelper::Button::GenericFeatureButton,
            :options => {:feature => :stop}),
          included_class.button(
            :instance_start,
            nil,
            N_('Start this Instance'),
            N_('Start'),
            :image   => "power_on",
            :confirm => N_("Start this Instance?"),
            :klass   => ApplicationHelper::Button::GenericFeatureButton,
            :options => {:feature => :start}),
          included_class.button(
            :instance_pause,
            nil,
            N_('Pause this Instance'),
            N_('Pause'),
            :image   => "power_pause",
            :confirm => N_("Pause this Instance?"),
            :klass   => ApplicationHelper::Button::GenericFeatureButton,
            :options => {:feature => :pause}),
          included_class.button(
            :instance_suspend,
            nil,
            N_('Suspend this Instance'),
            N_('Suspend'),
            :image   => "suspend",
            :confirm => N_("Suspend this Instance?"),
            :klass   => ApplicationHelper::Button::GenericFeatureButton,
            :options => {:feature => :suspend}),
          included_class.button(
            :instance_shelve,
            nil,
            N_('Shelve this Instance'),
            N_('Shelve'),
            :image   => "power_shelve",
            :confirm => N_("Shelve this Instance?"),
            :klass   => ApplicationHelper::Button::GenericFeatureButton,
            :options => {:feature => :shelve}),
          included_class.button(
            :instance_shelve_offload,
            nil,
            N_('Shelve Offload this Instance'),
            N_('Shelve Offload'),
            :image   => "power_shelve_offload",
            :confirm => N_("Shelve Offload this Instance?"),
            :klass   => ApplicationHelper::Button::GenericFeatureButton,
            :options => {:feature => :shelve_offload}),
          included_class.button(
            :instance_resume,
            nil,
            N_('Resume this Instance'),
            N_('Resume'),
            :image   => "power_resume",
            :confirm => N_("Resume this Instance?"),
            :klass   => ApplicationHelper::Button::GenericFeatureButton,
            :options => {:feature => :start}),
          included_class.separator,
          included_class.button(
            :instance_guest_restart,
            nil,
            N_('Soft Reboot this Instance'),
            N_('Soft Reboot'),
            :image   => "power_reset",
            :confirm => N_("Soft Reboot this Instance?"),
            :klass   => ApplicationHelper::Button::GenericFeatureButton,
            :options => {:feature => :reboot_guest}),
          included_class.button(
            :instance_reset,
            nil,
            N_('Hard Reboot the Guest OS on this Instance'),
            N_('Hard Reboot'),
            :image   => "guest_restart",
            :confirm => N_("Hard Reboot the Guest OS on this Instance?"),
            :klass   => ApplicationHelper::Button::InstanceReset),
          included_class.button(
            :instance_terminate,
            nil,
            N_('Delete this Instance'),
            N_('Delete'),
            :image   => "power_off",
            :confirm => N_("Delete this Instance?"),
            :klass   => ApplicationHelper::Button::GenericFeatureButton,
            :options => {:feature => :terminate}),
        ]
      ),
    ])
    included_class.button_group('vm_access', [
      included_class.select(
        :vm_remote_access_choice,
        'fa pficon-screen fa-lg',
        N_('VM Remote Access'),
        N_('Access'),
        :items => [
          included_class.button(
            :vm_vnc_console,
            'pficon pficon-screen fa-lg',
            N_('Open a web-based VNC or SPICE console for this VM'),
            N_('VM Console'),
            :url => "html5_console"),
        ]
      ),
    ])
  end
end
