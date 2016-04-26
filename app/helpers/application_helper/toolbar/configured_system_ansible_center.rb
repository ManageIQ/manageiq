class ApplicationHelper::Toolbar::ConfiguredSystemAnsibleCenter < ApplicationHelper::Toolbar::Basic
  button_group('provider_foreman_policy', [
    select(
      :provider_foreman_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :items => [
        button(
          :configured_system_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for this Configured System'),
          N_('Edit Tags'),
          :url       => "tagging",
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1+"),
      ]
    ),
  ])
end
