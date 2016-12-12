class ApplicationHelper::Toolbar::CloudVolumesCenter < ApplicationHelper::Toolbar::Basic
  button_group('cloud_volume_vmdb', [
                 select(
                   :cloud_volume_vmdb_choice,
                   'fa fa-cog fa-lg',
                   t = N_('Configuration'),
                   t,
                   :items => [
                     button(
                       :cloud_volume_new,
                       'pficon pficon-add-circle-o fa-lg',
                       t = N_('Add a new Cloud Volume'),
                       t,
                       :klass => ApplicationHelper::Button::CloudVolumeNew
                     ),
                     separator,
                     button(
                       :cloud_volume_attach,
                       'pficon pficon-volume fa-lg',
                       t = N_('Attach selected Cloud Volume to an Instance'),
                       t,
                       :url_parms => 'main_div',
                       :enabled   => false,
                       :onwhen    => '1'
                     ),
                     button(
                       :cloud_volume_detach,
                       'pficon pficon-volume fa-lg',
                       t = N_('Detach selected Cloud Volume from an Instance'),
                       t,
                       :url_parms => 'main_div',
                       :enabled   => false,
                       :onwhen    => '1'
                     ),
                     button(
                       :cloud_volume_edit,
                       'pficon pficon-edit fa-lg',
                       t = N_('Edit selected Cloud Volume'),
                       t,
                       :url_parms => 'main_div',
                       :enabled   => false,
                       :onwhen    => '1'
                     ),
                     button(
                       :cloud_volume_delete,
                       'pficon pficon-delete fa-lg',
                       t = N_('Delete selected Cloud Volumes'),
                       t,
                       :url_parms => 'main_div',
                       :confirm   => N_('Warning: The selected Cloud Volume and ALL of their components will be removed!'),
                       :enabled   => false,
                       :onwhen    => '1+'
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
      :enabled => "false",
      :onwhen  => "1+",
      :items   => [
        button(
          :cloud_volume_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit tags for the selected items'),
          N_('Edit Tags'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1+"),
      ]
    ),
  ])
end
