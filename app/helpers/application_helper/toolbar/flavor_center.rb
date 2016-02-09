class ApplicationHelper::Toolbar::FlavorCenter < ApplicationHelper::Toolbar::Basic
  button_group('flavor_policy', [
    {
      :buttonSelect => "flavor_policy_choice",
      :icon         => "fa fa-shield fa-lg",
      :title        => N_("Policy"),
      :text         => N_("Policy"),
      :items => [
        {
          :button       => "flavor_tag",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Tags"),
          :title        => N_("Edit Tags for this Flavor"),
        },
      ]
    },
  ])
end
