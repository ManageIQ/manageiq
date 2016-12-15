class ApplicationHelper::Toolbar::ContainerNodeCenter < ApplicationHelper::Toolbar::Basic
  button_group('container_node_monitoring', [
    select(
      :container_node_monitoring_choice,
      'product product-monitoring fa-lg',
      t = N_('Monitoring'),
      t,
      :items => [
        button(
          :container_node_timeline,
          'product product-timeline fa-lg',
          N_('Show Timelines for this Node'),
          N_('Timelines'),
          :url       => "/show",
          :url_parms => "?display=timeline",
          :options   => {:entity => 'Node'},
          :klass     => ApplicationHelper::Button::ContainerTimeline),
        button(
          :container_node_perf,
          'product product-monitoring fa-lg',
          N_('Show Capacity & Utilization data for this Node'),
          N_('Utilization'),
          :url       => "/show",
          :url_parms => "?display=performance"),
      ]
    ),
  ])
  button_group('container_node_policy', [
    select(
      :container_node_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :items => [
        button(
          :container_node_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for this Node'),
          N_('Edit Tags')),
        button(
          :container_node_protect,
          'pficon pficon-edit fa-lg',
          N_('Manage Policies for this Node'),
          N_('Manage Policies')),
        button(
          :container_node_check_compliance,
          'fa fa-search fa-lg',
          N_('Check Compliance of the last known configuration for this Node'),
          N_('Check Compliance of Last Known Configuration'),
          :confirm => N_("Initiate Check Compliance of the last known configuration for this item?")),
      ]
    ),
  ])
  button_group('vm_access', [
    button(
      :cockpit_console,
      'pficon pficon-screen fa-lg',
      N_('Open a new browser window with Cockpit for this VM.  This requires that Cockpit is pre-configured on the VM.'),
      N_('Web Console'),
      :url     => "launch_cockpit"),
  ])
end
