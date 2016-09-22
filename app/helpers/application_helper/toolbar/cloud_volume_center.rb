class ApplicationHelper::Toolbar::CloudVolumeCenter < ApplicationHelper::Toolbar::Basic
  button_group('cloud_volume_vmdb', [
                 select(
                   :cloud_volume_vmdb_choice,
                   'fa fa-cog fa-lg',
                   t = N_('Configuration'),
                   t,
                   :items => [
                     button(
                       :cloud_volume_backup_create,
                       'pficon pficon-volume fa-lg',
                       t = N_('Create a Backup of this Cloud Volume'),
                       t,
                       :klass     => ApplicationHelper::Button::VolumeBackupCreate,
                       :url_parms => 'main_div'
                     ),
                     button(
                       :cloud_volume_backup_restore,
                       'pficon pficon-volume fa-lg',
                       t = N_('Restore from a Backup of this Cloud Volume'),
                       t,
                       :klass     => ApplicationHelper::Button::VolumeBackupRestore,
                       :url_parms => 'main_div'
                     ),
                     button(
                       :cloud_volume_attach,
                       'pficon pficon-volume fa-lg',
                       t = N_('Attach this Cloud Volume to an Instance'),
                       t,
                       :klass     => ApplicationHelper::Button::VolumeAttach,
                       :url_parms => 'main_div'
                     ),
                     button(
                       :cloud_volume_detach,
                       'pficon pficon-volume fa-lg',
                       t = N_('Detach this Cloud Volume from an Instance'),
                       t,
                       :klass     => ApplicationHelper::Button::VolumeDetach,
                       :url_parms => 'main_div'
                     ),
                     button(
                       :cloud_volume_edit,
                       'pficon pficon-edit fa-lg',
                       t = N_('Edit this Cloud Volume'),
                       t,
                       :url_parms => 'main_div'
                     ),
                     button(
                       :cloud_volume_delete,
                       'pficon pficon-delete fa-lg',
                       t = N_('Delete this Cloud Volume'),
                       t,
                       :url_parms => 'main_div',
                       :confirm   => N_('Warning: This Cloud Volume and ALL of its components will be removed!')
                     ),
                   ]
                 )
               ])
  button_group('cloud_volume_policy', [
    select(
      :cloud_volume_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :items => [
        button(
          :cloud_volume_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit tags for this Cloud Volume'),
          N_('Edit Tags')),
      ]
    ),
  ])
end
