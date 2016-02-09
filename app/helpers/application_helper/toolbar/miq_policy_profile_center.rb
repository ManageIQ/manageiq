class ApplicationHelper::Toolbar::MiqPolicyProfileCenter < ApplicationHelper::Toolbar::Basic
  button_group('policy_profile_vmdb', [
    {
      :buttonSelect => "policy_profile_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "profile_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit this Policy Profile"),
          :title        => N_("Edit this Policy Profile"),
          :url_parms    => "main_div",
        },
        {
          :button       => "profile_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove this Policy Profile"),
          :title        => N_("Remove this Policy Profile"),
          :url_parms    => "main_div",
          :confirm      => N_("Are you sure you want to remove this Policy Profile?"),
        },
      ]
    },
  ])
end
