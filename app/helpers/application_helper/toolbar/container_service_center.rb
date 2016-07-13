class ApplicationHelper::Toolbar::ContainerServiceCenter < ApplicationHelper::Toolbar::Basic
  button_group('container_service_vmdb', [
    select(
      :container_service_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :container_service_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit this Service'),
          t,
          :url => "/edit"),
        button(
          :container_service_delete,
          'pficon pficon-delete fa-lg',
          t = N_('Remove this Service from the VMDB'),
          t,
          :url_parms => "&refresh=y",
          :confirm   => N_("Warning: This Service and ALL of its components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this Service?")),
      ]
    ),
  ])
  button_group('container_service_monitoring', [
    select(
      :container_service_monitoring_choice,
      'product product-monitoring fa-lg',
      t = N_('Monitoring'),
      t,
      :items => [
        button(
          :container_service_perf,
          'product product-monitoring fa-lg',
          N_('Show Capacity & Utilization data for this Service'),
          N_('Utilization'),
          :url       => "/show",
          :url_parms => "?display=performance"),
      ]
    ),
  ])
  button_group('container_service_policy', [
    select(
      :container_service_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :items => [
        button(
          :container_service_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for this Service'),
          N_('Edit Tags')),
      ]
    ),
  ])
end
