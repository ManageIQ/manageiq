class ApplicationHelper::Toolbar::AuthKeyPairCloudsCenter < ApplicationHelper::Toolbar::Basic
  button_group('auth_key_pair_cloud_policy', [
    select(
      :auth_key_pair_cloud_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :enabled => "false",
      :onwhen  => "1+",
      :items   => [
        button(
          :auth_key_pair_cloud_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit tags for the selected items'),
          N_('Edit Tags'),
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "1+"),
      ]
    ),
  ])
end
