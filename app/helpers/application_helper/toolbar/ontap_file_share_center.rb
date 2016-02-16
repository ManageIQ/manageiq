class ApplicationHelper::Toolbar::OntapFileShareCenter < ApplicationHelper::Toolbar::Basic
  button_group('ontap_file_share_vmdb', [
    select(
      :ontap_file_share_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :ontap_file_share_create_datastore,
          'pficon pficon-add-circle-o fa-lg',
          N_('Create a Datastore based on this #{ui_lookup(:model=>"OntapFileShare").split(" - ").last}'),
          N_('Create Datastore')),
      ]
    ),
  ])
  button_group('ontap_file_share_policy', [
    select(
      :ontap_file_share_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :items => [
        button(
          :ontap_file_share_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for this #{ui_lookup(:model=>"OntapFileShare").split(" - ").last}'),
          N_('Edit Tags')),
      ]
    ),
  ])
  button_group('ontap_file_share_monitoring', [
    select(
      :ontap_file_share_monitoring_choice,
      'product product-monitoring fa-lg',
      t = N_('Monitoring'),
      t,
      :items => [
        button(
          :ontap_file_share_statistics,
          'product product-monitoring fa-lg',
          N_('Show Utilization for this #{ui_lookup(:model=>"OntapFileShare").split(" - ").last}'),
          N_('Utilization'),
          :url => "/show_statistics"),
      ]
    ),
  ])
end
