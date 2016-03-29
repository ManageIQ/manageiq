class ApplicationHelper::Toolbar::CloudVolumeCenter < ApplicationHelper::Toolbar::Basic
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
                       N_('Edit tags for this #{ui_lookup(:table=>"cloud_volumes")}'),
                       N_('Edit Tags')),
                   ]
                 ),
               ])
  button_group('cloud_volume_vmdb', [
                 select(
                   :cloud_volume_vmdb_choice,
                   'fa fa-cog fa-lg',
                   t = N_('Configuration'),
                   t,
                   :items => [
                     button(
                       :cloud_volume_attach,
                       'pficon pficon-volume fa-lg',
                       t = N_('Attach this Cloud Volume to an Instance'),
                       t,
                       :url_parms => 'main_div',
                     ),
                     button(
                       :cloud_volume_detach,
                       'pficon pficon-volume fa-lg',
                       t = N_('Detach this Cloud Volume from an Instance'),
                       t,
                       :url_parms => 'main_div',
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
                       :url_parms => '&refresh=y',
                       :confirm   => 'Warning: This Cloud Volume and ALL of its components will be removed. Are you sure you want to remove this Cloud Volume?'
                     ),
                   ]
                 )
               ])
end
