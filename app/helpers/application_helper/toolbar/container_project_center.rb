class ApplicationHelper::Toolbar::ContainerProjectCenter < ApplicationHelper::Toolbar::Basic
  button_group('container_project_monitoring', [
    select(
      :container_project_monitoring_choice,
      'product product-monitoring fa-lg',
      t = N_('Monitoring'),
      t,
      :items => [
        button(
          :container_project_timeline,
          'product product-timeline fa-lg',
          N_('Show Timelines for this Project'),
          N_('Timelines'),
          :url       => "/show",
          :url_parms => "?display=timeline",
          :options   => {:entity => 'Project'},
          :klass     => ApplicationHelper::Button::ContainerTimeline),
        button(
          :container_project_perf,
          'product product-monitoring fa-lg',
          N_('Show Capacity & Utilization data for this Project'),
          N_('Utilization'),
          :url       => "/show",
          :url_parms => "?display=performance"),
      ]
    ),
  ])
  button_group('container_project_policy', [
    select(
      :container_project_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :items => [
        button(
          :container_project_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for this Node'),
          N_('Edit Tags')),
      ]
    ),
  ])
end
