class ApplicationHelper::Toolbar::HostAggregatesCenter < ApplicationHelper::Toolbar::Basic
  button_group('host_aggregate_vmdb', [
    select(
      :host_aggregate_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :host_aggregate_new,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Add a New Host Aggregate'),
          t,
          :url => "/new"),
        button(
          :host_aggregate_edit,
          'pficon pficon-edit fa-lg',
          N_('Select a single Host Aggregate to edit'),
          N_('Edit Selected Host Aggregate'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1"),
        button(
          :host_aggregate_delete,
          'pficon pficon-delete fa-lg',
          N_('Delete selected Host Aggregates'),
          N_('Delete Host Aggregates'),
          :url_parms => "main_div",
          :confirm   => N_("Warning: The selected Host Aggregates will be permanently deleted!"),
          :enabled   => false,
          :onwhen    => "1+"),
      ]
    ),
  ])
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
