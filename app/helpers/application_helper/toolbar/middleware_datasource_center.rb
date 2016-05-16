class ApplicationHelper::Toolbar::MiddlewareDatasourceCenter < ApplicationHelper::Toolbar::Basic
  button_group('middleware_datasource_policy', [
    select(
      :middleware_datasource_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :enabled => "false",
      :items   => [
        button(
          :middleware_datasource_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for this #{ui_lookup(:table=>"middleware_datasource")}'),
          N_('Edit Tags')),
      ]
    ),
  ])
end
