class ApplicationHelper::Toolbar::HostAggregateCenter < ApplicationHelper::Toolbar::Basic
  button_group('host_aggregate_policy', [
    select(
      :host_aggregate_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :items => [
        button(
          :host_aggregate_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for this Host Aggregate'),
          N_('Edit Tags')),
      ]
    ),
  ])
end
