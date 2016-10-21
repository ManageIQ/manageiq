class ApplicationHelper::Toolbar::HostAggregateCenter < ApplicationHelper::Toolbar::Basic
  button_group('host_aggregate_vmdb', [
    select(
      :host_aggregate_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :host_aggregate_edit,
          'pficon pficon-edit fa-lg',
          N_('Select this Host Aggregate'),
          N_('Edit Host Aggregate'),
          :url_parms => "main_div",
          :klass     => ApplicationHelper::Button::GenericFeatureButtonWithDisable,
          :options   => {:feature => :update_aggregate}
        ),
        button(
          :host_aggregate_delete,
          'pficon pficon-delete fa-lg',
          N_('Delete selected Host Aggregates'),
          N_('Delete Host Aggregates'),
          :url_parms => "main_div",
          :confirm   => N_("Warning: The selected Host Aggregates will be permanently deleted!"),
          :klass     => ApplicationHelper::Button::GenericFeatureButtonWithDisable,
          :options   => {:feature => :delete_aggregate}
        ),
      ]
    ),
  ])
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
