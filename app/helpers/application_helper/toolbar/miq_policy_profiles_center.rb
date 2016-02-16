class ApplicationHelper::Toolbar::MiqPolicyProfilesCenter < ApplicationHelper::Toolbar::Basic
  button_group('policy_profile_vmdb', [
    select(
      :policy_profile_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :profile_new,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Add a New Policy Profile'),
          t),
      ]
    ),
  ])
end
