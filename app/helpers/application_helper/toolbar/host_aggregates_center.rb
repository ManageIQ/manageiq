class ApplicationHelper::Toolbar::HostAggregatesCenter < ApplicationHelper::Toolbar::Basic
  button_group('host_aggregate_policy', [
    select(
      :host_aggregate_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :enabled => false,
      :onwhen  => "1+",
      :items   => [
        button(
          :host_aggregate_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for the selected Host Aggregates'),
          N_('Edit Tags'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1+"),
      ]
    ),
  ])
end
