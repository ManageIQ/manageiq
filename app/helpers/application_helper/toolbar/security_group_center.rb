class ApplicationHelper::Toolbar::SecurityGroupCenter < ApplicationHelper::Toolbar::Basic
  button_group('security_group_policy', [
    select(:security_group_policy_choice, 'fa fa-shield fa-lg', N_('Policy'), N_('Policy'),
      :items     => [
        button(:security_group_tag, 'pficon pficon-edit fa-lg', N_('Edit Tags for this Security Group'), N_('Edit Tags')),
      ]
    ),
  ])
end
