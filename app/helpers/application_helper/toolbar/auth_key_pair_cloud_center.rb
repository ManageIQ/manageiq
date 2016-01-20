class ApplicationHelper::Toolbar::AuthKeyPairCloudCenter < ApplicationHelper::Toolbar::Basic
  button_group('auth_key_pair_cloud_policy', [
    select(
      :auth_key_pair_cloud_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :items => [
        button(
          :auth_key_pair_cloud_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit tags for this Key Pair'),
          N_('Edit Tags')),
      ]
    ),
  ])
  button_group('auth_key_pair_cloud_vmdb', [
    select(
      :auth_key_pair_cloud_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :auth_key_pair_cloud_delete,
          'pficon pficon-delete fa-lg',
          t = N_('Remove this #{ui_lookup(:table=>"auth_key_pair_cloud")}'),
          t,
          :url_parms => "&refresh=y",
          :confirm   => N_("Warning: The selected \#{ui_lookup(:table=>\"auth_key_pair_cloud\")} and ALL of its components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove the selected \#{ui_lookup(:table=>\"auth_key_pair_cloud\")}")),
      ]
    ),
  ])
end
