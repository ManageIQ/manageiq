class ApplicationHelper::Toolbar::HostCenter < ApplicationHelper::Toolbar::Basic
  button_group('host_vmdb', [
    select(
      :host_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :host_refresh,
          'fa fa-refresh fa-lg',
          N_('Refresh relationships and power states for all items related to this item'),
          N_('Refresh Relationships and Power States'),
          :confirm => N_("Refresh relationships and power states for all items related to this item?"),
          :klass => ApplicationHelper::Button::HostRefresh),
        button(
          :host_scan,
          'fa fa-search fa-lg',
          N_('Perform SmartState Analysis on this item'),
          N_('Perform SmartState Analysis'),
          :confirm => N_("Perform SmartState Analysis on this item?"),
          :klass => ApplicationHelper::Button::HostScan),
        button(
          :host_manageable,
          'pficon pficon-edit fa-lg',
          N_('Set this item to manageable state'),
          N_('Set Node to Manageable'),
          :confirm => N_("Set this item to manageable?"),
          :klass   => ApplicationHelper::Button::HostManageable),
        button(
          :host_introspect,
          'pficon pficon-edit fa-lg',
          N_('Introspect this item'),
          N_('Introspect Node'),
          :confirm => N_("Introspect this item?"),
          :klass   => ApplicationHelper::Button::HostIntrospectProvide),
        button(
          :host_provide,
          'pficon pficon-edit fa-lg',
          N_('Provide this item'),
          N_('Provide Node'),
          :confirm => N_("Provide this item?"),
          :klass   => ApplicationHelper::Button::HostIntrospectProvide),
        separator,
        button(
          :host_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit this item'),
          t,
          :url => "/edit"),
        button(
          :host_toggle_maintenance,
          'pficon pficon-edit fa-lg',
          N_('Toggle maintenance mode for this item'),
          N_('Toggle Maintenance Mode'),
          :klass   => ApplicationHelper::Button::HostToggleMaintenance,
          :confirm => N_("Toggle maintenance mode for this item?")),
        button(
          :host_delete,
          'pficon pficon-delete fa-lg',
          N_('Remove this item'),
          N_('Remove item'),
          :url_parms => "&refresh=y",
          :confirm   => N_("Warning: This item and ALL of its components will be permanently removed!?")),
      ]
    ),
  ])
  button_group('host_policy', [
    select(
      :host_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :items => [
        button(
          :host_protect,
          'pficon pficon-edit fa-lg',
          N_('Manage Policies for this item'),
          N_('Manage Policies'),
          :klass => ApplicationHelper::Button::HostProtect),
        button(
          :host_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for this item'),
          N_('Edit Tags')),
        button(
          :host_check_compliance,
          'fa fa-search fa-lg',
          N_('Check Compliance of the last known configuration for this item'),
          N_('Check Compliance of Last Known Configuration'),
          :confirm => N_("Initiate Check Compliance of the last known configuration for this item?")),
        button(
          :host_analyze_check_compliance,
          'fa fa-search fa-lg',
          N_('Analyze then Check Compliance for this item'),
          N_('Analyze then Check Compliance'),
          :confirm => N_("Analyze then Check Compliance for this item?")),
      ]
    ),
  ])
  button_group('host_lifecycle', [
    select(
      :host_lifecycle_choice,
      'fa fa-recycle fa-lg',
      t = N_('Lifecycle'),
      t,
      :items => [
        button(
          :host_miq_request_new,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Provision this item'),
          t),
      ]
    ),
  ])
  button_group('host_monitoring', [
    select(
      :host_monitoring_choice,
      'product product-monitoring fa-lg',
      t = N_('Monitoring'),
      t,
      :items => [
        button(
          :host_perf,
          'product product-monitoring fa-lg',
          N_('Show Capacity & Utilization data for this item'),
          N_('Utilization'),
          :url       => "/show",
          :url_parms => "?display=performance"),
        button(
          :host_timeline,
          'product product-timeline fa-lg',
          N_('Show Timelines for this item'),
          N_('Timelines'),
          :url       => "/show",
          :url_parms => "?display=timeline"),
      ]
    ),
  ])
  button_group('host_operations', [
    select(
      :host_power_choice,
      'fa fa-power-off fa-lg',
      N_('Power Functions'),
      N_('Power'),
      :items => [
        button(
          :host_enter_maint_mode,
          nil,
          N_('Put this item into Maintenance Mode'),
          N_('Enter Maintenance Mode'),
          :image   => "enter_maint_mode",
          :confirm => N_("Put this item into Maintenance Mode?"),
          :klass   => ApplicationHelper::Button::GenericFeatureButton,
          :options => {:feature => :enter_maint_mode}),
        button(
          :host_exit_maint_mode,
          nil,
          N_('Take this item out of Maintenance Mode'),
          N_('Exit Maintenance Mode'),
          :image   => "exit_maint_mode",
          :confirm => N_("Take this item out of Maintenance Mode?"),
          :klass   => ApplicationHelper::Button::GenericFeatureButton,
          :options => {:feature => :exit_maint_mode}),
        button(
          :host_standby,
          nil,
          N_('Shutdown this item to Standby Mode'),
          N_('Enter Standby Mode'),
          :image   => "standby",
          :confirm => N_("Shutdown this item to Standby Mode?"),
          :klass   => ApplicationHelper::Button::HostFeatureButton,
          :options => {:feature => :standby}),
        button(
          :host_shutdown,
          nil,
          N_('Shutdown this item'),
          N_('Shutdown'),
          :image   => "guest_shutdown",
          :confirm => N_("Shutdown this item?"),
          :klass   => ApplicationHelper::Button::HostFeatureButtonWithDisable,
          :options => {:feature => :shutdown}),
        button(
          :host_reboot,
          nil,
          N_('Restart this item'),
          N_('Restart'),
          :image   => "guest_restart",
          :confirm => N_("Restart this item?"),
          :klass   => ApplicationHelper::Button::HostFeatureButton,
          :options => {:feature => :reboot}),
        separator,
        button(
          :host_start,
          nil,
          N_('Power On this item'),
          N_('Power On'),
          :image   => "power_on",
          :confirm => N_("Power On this item?"),
          :klass   => ApplicationHelper::Button::HostFeatureButton,
          :options => {:feature => :start}),
        button(
          :host_stop,
          nil,
          N_('Power Off this item'),
          N_('Power Off'),
          :image   => "power_off",
          :confirm => N_("Power Off this item?"),
          :klass   => ApplicationHelper::Button::HostFeatureButton,
          :options => {:feature => :stop}),
        button(
          :host_reset,
          nil,
          N_('Reset this item'),
          N_('Reset'),
          :image   => "power_reset",
          :confirm => N_("Reset this item?"),
          :klass   => ApplicationHelper::Button::HostFeatureButtonWithDisable,
          :options => {:feature => :reset}),
      ]
    ),
  ])
end
