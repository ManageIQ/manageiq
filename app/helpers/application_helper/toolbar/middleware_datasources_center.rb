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
  button_group(
    'middleware_datasource_operations', [
      select(
        :middleware_datasource_operations_choice,
        'fa fa-play-circle-o fa-lg',
        t = N_('Operations'),
        t,
        :enabled => false,
        :onwhen  => "1+",
        :items   => [
          button(
            :middleware_datasource_remove,
            'pficon pficon-delete fa-lg',
            N_('Remove Middleware Datasources'),
            N_('Remove'),
            :url_parms => "main_div",
            :enabled   => false,
            :onwhen    => "1+",
            :confirm   => N_('Do you want to remove these Datasources ? Some Applications could be using these '\
                             'Datasources and may malfunction if they are deleted.')
          )
        ]
      ),
    ])
end
