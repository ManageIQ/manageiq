class ApplicationHelper::Toolbar::MiddlewareDatasourcesCenter < ApplicationHelper::Toolbar::Basic
  button_group('middleware_datasource_policy', [
    select(
      :middleware_datasource_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :enabled => false,
      :onwhen  => "1+",
      :items   => [
        button(
          :middleware_datasource_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for these Middleware Datasources'),
          N_('Edit Tags'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1+"),
      ]
    ),
  ])
end
