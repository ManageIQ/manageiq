class ApplicationHelper::Toolbar::EmsMiddlewareCenter < ApplicationHelper::Toolbar::Basic
  button_group('ems_middleware_vmdb', [
    select(
      :ems_middleware_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :ems_middleware_refresh,
          'fa fa-refresh fa-lg',
          N_('Refresh items and relationships related to this Middleware Provider'),
          N_('Refresh items and relationships'),
          :confirm => N_("Refresh items and relationships related to this Middleware Provider?")),
        separator,
        button(
          :ems_middleware_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit this Middleware Provider'),
          t,
          :url => "/edit"),
        button(
          :ems_middleware_delete,
          'pficon pficon-delete fa-lg',
          t = N_('Remove this Middleware Provider from the VMDB'),
          t,
          :url_parms => "&refresh=y",
          :confirm   => N_("Warning: This Middleware Provider and ALL of its components will be permanently removed from the Virtual Management Database. Are you sure you want to remove this Middleware Provider?")),
      ]
    ),
  ])
  button_group('ems_middleware_monitoring', [
    select(
      :ems_middlewarer_monitoring_choice,
      'product product-monitoring fa-lg',
      t = N_('Monitoring'),
      t,
      :items => [
        button(
          :ems_middleware_timeline,
          'product product-timeline fa-lg',
          N_('Show Timelines for this Middleware Provider'),
          N_('Timelines'),
          :url       => "/show",
          :url_parms => "?display=timeline"),
      ]
    ),
  ])
  button_group('ems_middleware_policy', [
    select(
      :ems_middleware_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :items => [
        button(
          :ems_middleware_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for this Middleware Provider'),
          N_('Edit Tags')),
      ]
    ),
  ])
end
