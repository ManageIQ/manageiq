class ApplicationHelper::Toolbar::ContainersCenter < ApplicationHelper::Toolbar::Basic
  button_group('container_policy', [
    select(
      :container_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :enabled => false,
      :onwhen  => "1+",
      :items   => [
        button(
          :container_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for selected Containers'),
          N_('Edit Tags'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1+"),
      ]
    ),
  ])
end
