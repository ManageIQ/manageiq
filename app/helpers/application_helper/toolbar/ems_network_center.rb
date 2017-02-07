class ApplicationHelper::Toolbar::EmsNetworkCenter < ApplicationHelper::Toolbar::Basic
  button_group('ems_network_vmdb', [
    button(
      :refresh_server_summary,
      'fa fa-repeat fa-lg',
      N_('Reload Current Display'),
      nil),
    select(
      :ems_network_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :ems_network_refresh,
          'fa fa-refresh fa-lg',
          N_('Refresh relationships and power states for all items related to this Network Provider'),
          N_('Refresh Relationships and Power States'),
          :confirm => N_("Refresh relationships and power states for all items related to this Network Provider?")),
        separator,
        button(
          :ems_network_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit this Network Provider'),
          t),
        button(
          :ems_network_delete,
          'pficon pficon-delete fa-lg',
          t = N_('Remove this Network Provider'),
          t,
          :url_parms => "&refresh=y",
          :confirm   => N_("Warning: This Network Provider and ALL of its components will be permanently removed!")),
      ]
    ),
  ])
  button_group('ems_network_policy', [
    select(
      :ems_network_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :items => [
        button(
          :ems_network_protect,
          'pficon pficon-edit fa-lg',
          N_('Manage Policies for this Network Provider'),
          N_('Manage Policies')),
        button(
          :ems_network_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for this Network Provider'),
          N_('Edit Tags')),
      ]
    ),
  ])
  button_group('ems_network_monitoring', [
    select(
      :ems_network_monitoring_choice,
      'product product-monitoring fa-lg',
      t = N_('Monitoring'),
      t,
      :items => [
        button(
          :ems_network_timeline,
          'product product-timeline fa-lg',
          N_('Show Timelines for this Network Provider'),
          N_('Timelines'),
          :klass     => ApplicationHelper::Button::EmsTimeline,
          :url_parms => "?display=timeline"),
      ]
    ),
  ])
end
