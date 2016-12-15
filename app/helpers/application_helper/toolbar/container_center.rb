class ApplicationHelper::Toolbar::ContainerCenter < ApplicationHelper::Toolbar::Basic
  button_group('container_monitoring', [
    select(
      :container_monitoring_choice,
      'product product-monitoring fa-lg',
      t = N_('Monitoring'),
      t,
      :items => [
        button(
          :container_timeline,
          'product product-timeline fa-lg',
          N_('Show Timelines for this Container'),
          N_('Timelines'),
          :url_parms => "?display=timeline",
          :options   => {:entity => 'Container'},
          :klass     => ApplicationHelper::Button::ContainerTimeline),
        button(
          :container_perf,
          'product product-monitoring fa-lg',
          N_('Show Capacity & Utilization data for this Container'),
          N_('Utilization'),
          :url_parms => "?display=performance"),
      ]
    ),
  ])
  button_group('container_policy', [
    select(
      :container_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :items => [
        button(
          :container_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for this Container'),
          N_('Edit Tags'),
          :url_parms => "main_div"),
      ]
    ),
  ])
end
