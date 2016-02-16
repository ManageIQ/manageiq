class ApplicationHelper::Toolbar::OntapStorageVolumeCenter < ApplicationHelper::Toolbar::Basic
  button_group('ontap_storage_volume_policy', [
    select(
      :ontap_storage_volume_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :items => [
        button(
          :ontap_storage_volume_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for this Volume'),
          N_('Edit Tags')),
      ]
    ),
  ])
  button_group('ontap_storage_volume_monitoring', [
    select(
      :ontap_storage_volume_monitoring_choice,
      'product product-monitoring fa-lg',
      t = N_('Monitoring'),
      t,
      :items => [
        button(
          :ontap_storage_volume_statistics,
          'product product-monitoring fa-lg',
          N_('Show Utilization for this Storage System'),
          N_('Utilization'),
          :url => "/show_statistics"),
      ]
    ),
  ])
end
