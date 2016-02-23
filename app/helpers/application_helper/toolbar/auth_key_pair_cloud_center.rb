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
end
