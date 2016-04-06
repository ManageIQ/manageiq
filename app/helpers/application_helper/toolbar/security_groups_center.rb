class ApplicationHelper::Toolbar::SecurityGroupsCenter < ApplicationHelper::Toolbar::Basic
  button_group('security_group_policy', [
    select(
      :security_group_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :enabled => false,
      :onwhen  => "1+",
      :items   => [
        button(
          :security_group_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for the selected Security Groups'),
          N_('Edit Tags'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1+"),
      ]
    ),
  ])
end
