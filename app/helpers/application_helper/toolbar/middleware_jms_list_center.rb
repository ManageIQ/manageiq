class ApplicationHelper::Toolbar::MiddlewareJmsListCenter < ApplicationHelper::Toolbar::Basic
  button_group('middleware_jms_policy', [
    select(
      :middleware_jms_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :enabled => false,
      :onwhen  => "1+",
      :items   => [
        button(
          :middleware_jms_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for these Middleware JMS'),
          N_('Edit Tags'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1+"),
      ]
    ),
  ])
end
