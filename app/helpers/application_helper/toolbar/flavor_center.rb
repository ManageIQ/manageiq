class ApplicationHelper::Toolbar::FlavorCenter < ApplicationHelper::Toolbar::Basic
  button_group('flavor_policy', [
    select(
      :flavor_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :items => [
        button(
          :flavor_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for this Flavor'),
          N_('Edit Tags')),
      ]
    ),
  ])
end
