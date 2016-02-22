class ApplicationHelper::Toolbar::CloudVolumeSnapshotCenter < ApplicationHelper::Toolbar::Basic
  button_group('cloud_volume_snapshot_policy', [
    select(
      :cloud_volume_snapshot_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :items => [
        button(
          :cloud_volume_snapshot_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit tags for this #{ui_lookup(:table=>"cloud_volume_snapshots")}'),
          N_('Edit Tags')),
      ]
    ),
  ])
end
