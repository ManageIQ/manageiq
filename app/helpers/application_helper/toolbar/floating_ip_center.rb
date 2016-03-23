class ApplicationHelper::Toolbar::FloatingIpCenter < ApplicationHelper::Toolbar::Basic
  button_group('floating_ip_policy', [
    select(
      :floating_ip_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :items => [
        button(
          :floating_ip_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for this Floating IP'),
          N_('Edit Tags')),
      ]
    ),
  ])
end
