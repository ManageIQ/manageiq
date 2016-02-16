class ApplicationHelper::Toolbar::OntapStorageVolumesCenter < ApplicationHelper::Toolbar::Basic
  button_group('ontap_storage_volume_policy', [
    select(
      :ontap_storage_volume_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :enabled => "false",
      :onwhen  => "1+",
      :items   => [
        button(
          :ontap_storage_volume_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit tags for the selected Volumes'),
          N_('Edit Tags'),
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "1+"),
      ]
    ),
  ])
end
