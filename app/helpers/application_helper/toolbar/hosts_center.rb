class ApplicationHelper::Toolbar::HostsCenter < ApplicationHelper::Toolbar::Basic
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
          N_('Refresh relationships and power states for all items related to the selected items'),
          N_('Refresh Relationships and Power States'),
          :url_parms => "main_div",
          :confirm   => N_("Refresh relationships and power states for all items related to the selected items?"),
          :enabled   => "false",
          :onwhen    => "1+"),
        button(
          :host_scan,
          'fa fa-search fa-lg',
          N_('Perform SmartState Analysis on the selected items'),
          N_('Perform SmartState Analysis'),
          :url_parms => "main_div",
          :confirm   => N_("Perform SmartState Analysis on the selected items?"),
          :enabled   => "false",
          :onwhen    => "1+"),
        button(
          :host_compare,
          'product product-compare fa-lg',
          N_('Select two or more items to compare'),
          N_('Compare Selected items'),
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "2+"),
        button(
          :host_discover,
          'fa fa-search fa-lg',
          t = N_('Discover items'),
          t,
          :url       => "/discover",
          :url_parms => "?discover_type=hosts"),
        separator,
        button(
          :host_new,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Add a New item'),
          t,
          :url => "/new"),
        button(
          :host_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit Selected items'),
          t,
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "1+"),
        button(
          :host_delete,
          'pficon pficon-delete fa-lg',
          N_('Remove Selected items from the VMDB'),
          N_('Remove items from the VMDB'),
          :url_parms => "main_div",
          :confirm   => N_("Warning: The selected items and ALL of their components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove the selected items?"),
          :enabled   => "false",
          :onwhen    => "1+"),
      ]
    ),
  ])
  button_group('host_policy', [
    select(
      :host_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :enabled => "false",
      :onwhen  => "1+",
      :items   => [
        button(
          :host_protect,
          'pficon pficon-edit fa-lg',
          N_('Manage Policies for the selected items'),
          N_('Manage Policies'),
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "1+"),
        button(
          :host_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for the selected items'),
          N_('Edit Tags'),
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "1+"),
        button(
          :host_check_compliance,
          'fa fa-search fa-lg',
          N_('Check Compliance of the last known configuration for the selected items'),
          N_('Check Compliance of Last Known Configuration'),
          :url_parms => "main_div",
          :confirm   => N_("Initiate Check Compliance of the last known configuration for the selected items?"),
          :enabled   => "false",
          :onwhen    => "1+"),
        button(
          :host_analyze_check_compliance,
          'fa fa-search fa-lg',
          N_('Analyze then Check Compliance for the selected items'),
          N_('Analyze then Check Compliance'),
          :url_parms => "main_div",
          :confirm   => N_("Analyze then Check Compliance for the selected items?"),
          :enabled   => "false",
          :onwhen    => "1+"),
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
          N_('Request to Provision items'),
          N_('Provision items'),
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "1+"),
      ]
    ),
  ])
  button_group('host_operations', [
    select(
      :host_power_choice,
      'fa fa-power-off fa-lg',
      N_('Power Operations'),
      N_('Power'),
      :enabled => "false",
      :onwhen  => "1+",
      :items   => [
        button(
          :host_standby,
          nil,
          N_('Shutdown the selected items to Standby Mode'),
          N_('Enter Standby Mode'),
          :image     => "standby",
          :confirm   => N_("Shutdown the selected items to Standy Mode?"),
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "1+"),
        button(
          :host_shutdown,
          nil,
          N_('Shutdown the selected items'),
          N_('Shutdown'),
          :image     => "guest_shutdown",
          :url_parms => "main_div",
          :confirm   => N_("Shutdown the selected items?"),
          :enabled   => "false",
          :onwhen    => "1+"),
        button(
          :host_reboot,
          nil,
          N_('Restart the selected items'),
          N_('Restart'),
          :image     => "guest_restart",
          :url_parms => "main_div",
          :confirm   => N_("Restart the selected items?"),
          :enabled   => "false",
          :onwhen    => "1+"),
        separator,
        button(
          :host_start,
          nil,
          N_('Power On the selected items'),
          N_('Power On'),
          :image     => "power_on",
          :url_parms => "main_div",
          :confirm   => N_("Power On the selected items?")),
        button(
          :host_stop,
          nil,
          N_('Power Off the selected items'),
          N_('Power Off'),
          :image     => "power_off",
          :url_parms => "main_div",
          :confirm   => N_("Power Off the selected items?")),
        button(
          :host_reset,
          nil,
          N_('Reset the selected items'),
          N_('Reset'),
          :image     => "power_reset",
          :url_parms => "main_div",
          :confirm   => N_("Reset the selected items?")),
      ]
    ),
  ])
end
