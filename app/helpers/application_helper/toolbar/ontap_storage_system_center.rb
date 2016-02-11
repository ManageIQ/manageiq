class ApplicationHelper::Toolbar::OntapStorageSystemCenter < ApplicationHelper::Toolbar::Basic
  button_group('ontap_storage_system_vmdb', [
    select(
      :ontap_storage_system_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :ontap_storage_system_create_logical_disk,
          'pficon pficon-add-circle-o fa-lg',
          N_('Create a Logical Disk (NetApp Flexible Volume) on this #{ui_lookup(:model=>"OntapStorageSystem").split(" - ").last}'),
          N_('Create Logical Disk')),
      ]
    ),
  ])
  button_group('ontap_storage_system_policy', [
    select(
      :ontap_storage_system_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :items => [
        button(
          :ontap_storage_system_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for this #{ui_lookup(:model=>"OntapStorageSystem").split(" - ").last}'),
          N_('Edit Tags')),
      ]
    ),
  ])
  button_group('ontap_storage_system_monitoring', [
    select(
      :ontap_storage_system_monitoring_choice,
      'product product-monitoring fa-lg',
      t = N_('Monitoring'),
      t,
      :items => [
        button(
          :ontap_storage_system_statistics,
          'product product-monitoring fa-lg',
          N_('Show Utilization for this #{ui_lookup(:model=>"OntapStorageSystem").split(" - ").last}'),
          N_('Utilization'),
          :url => "/show_statistics"),
      ]
    ),
  ])
end
