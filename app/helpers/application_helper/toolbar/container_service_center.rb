class ApplicationHelper::Toolbar::ContainerServiceCenter < ApplicationHelper::Toolbar::Basic
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
