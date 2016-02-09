class ApplicationHelper::Toolbar::MiqPolicyProfilesCenter < ApplicationHelper::Toolbar::Basic
  button_group('policy_profile_vmdb', [
    {
      :buttonSelect => "policy_profile_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "profile_new",
          :icon         => "pficon pficon-add-circle-o fa-lg",
          :text         => N_("Add a New Policy Profile"),
          :title        => N_("Add a New Policy Profile"),
        },
      ]
    },
  ])
end
