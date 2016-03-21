class ApplicationHelper::Toolbar::CloudSubnetsCenter < ApplicationHelper::Toolbar::Basic
  button_group('cloud_subnet_policy', [
    select(
      :cloud_subnet_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :enabled => "false",
      :onwhen  => "1+",
      :items   => [
        button(
          :cloud_subnet_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for the selected Floating IPs'),
          N_('Edit Tags'),
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "1+"),
      ]
    ),
  ])
end
