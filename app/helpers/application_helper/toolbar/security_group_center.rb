class ApplicationHelper::Toolbar::SecurityGroupCenter < ApplicationHelper::Toolbar::Basic
  button_group('security_group_policy', [
    {
      :buttonSelect => "security_group_policy_choice",
      :icon         => "fa fa-shield fa-lg",
      :title        => N_("Policy"),
      :text         => N_("Policy"),
      :items => [
        {
          :button       => "security_group_tag",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Tags"),
          :title        => N_("Edit Tags for this Security Group"),
        },
      ]
    },
  ])
end
