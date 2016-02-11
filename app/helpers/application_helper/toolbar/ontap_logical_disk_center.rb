class ApplicationHelper::Toolbar::OntapLogicalDiskCenter < ApplicationHelper::Toolbar::Basic
  button_group('ontap_logical_disk_policy', [
    select(
      :ontap_logical_disk_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :items => [
        button(
          :ontap_logical_disk_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for this Logical Disk'),
          N_('Edit Tags')),
      ]
    ),
  ])
  button_group('ontap_logical_disk_monitoring', [
    select(
      :ontap_logical_disk_monitoring_choice,
      'product product-monitoring fa-lg',
      t = N_('Monitoring'),
      t,
      :items => [
        button(
          :ontap_logical_disk_perf,
          'product product-monitoring fa-lg',
          N_('Show Capacity & Utilization data for this Logical Disk'),
          N_('Utilization'),
          :url       => "/show",
          :url_parms => "?display=performance"),
        button(
          :ontap_logical_disk_statistics,
          'product product-monitoring fa-lg',
          N_('Show Utilization Statistics for this Logical Disk'),
          N_('Statistics'),
          :url => "/show_statistics"),
      ]
    ),
  ])
end
