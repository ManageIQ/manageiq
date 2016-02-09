class ApplicationHelper::Toolbar::FlavorsCenter < ApplicationHelper::Toolbar::Basic
  button_group('flavor_policy', [
    select(:flavor_policy_choice, 'fa fa-shield fa-lg', N_('Policy'), N_('Policy'),
      :enabled   => "false",
      :onwhen    => "1+",
      :items     => [
        button(:flavor_tag, 'pficon pficon-edit fa-lg', N_('Edit Tags for the selected Flavors'), N_('Edit Tags'),
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "1+"),
      ]
    ),
  ])
end
