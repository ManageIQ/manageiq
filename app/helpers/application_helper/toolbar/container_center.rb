class ApplicationHelper::Toolbar::ContainerCenter < ApplicationHelper::Toolbar::Basic
  button_group('container_vmdb', [
    select(
      :container_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :container_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit this Container'),
          t,
          :url => "/edit"),
        button(
          :container_delete,
          'pficon pficon-delete fa-lg',
          t = N_('Remove this Container from the VMDB'),
          t,
          :url_parms => "&refresh=y",
          :confirm   => N_("Warning: This Container and ALL of its components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this Container?")),
      ]
    ),
  ])
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
          :url_parms => "?display=timeline"),
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
