class ApplicationHelper::Toolbar::MiqPolicyProfilesCenter < ApplicationHelper::Toolbar::Basic
  button_group('policy_profile_vmdb', [
    select(:policy_profile_vmdb_choice, 'fa fa-cog fa-lg', N_('Configuration'), N_('Configuration'),
      :items     => [
        button(:profile_new, 'pficon pficon-add-circle-o fa-lg', N_('Add a New Policy Profile'), N_('Add a New Policy Profile')),
      ]
    ),
  ])
end
