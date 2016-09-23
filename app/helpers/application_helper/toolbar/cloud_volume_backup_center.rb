class ApplicationHelper::Toolbar::CloudVolumeBackupCenter < ApplicationHelper::Toolbar::Basic
  button_group('cloud_volume_backup_policy', [
    select(
      :cloud_volume_backup_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :items => [
        button(
          :cloud_volume_backup_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit tags for this Cloud Volume Backup'),
          N_('Edit Tags')),
      ]
    ),
  ])
end
