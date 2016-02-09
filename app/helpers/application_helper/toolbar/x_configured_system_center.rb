class ApplicationHelper::Toolbar::XConfiguredSystemCenter < ApplicationHelper::Toolbar::Basic
  button_group('record_summary', [
    {
      :buttonSelect => "provider_foreman_lifecycle_choice",
      :icon         => "fa fa-recycle fa-lg",
      :title        => N_("Lifecycle"),
      :text         => N_("Lifecycle"),
      :enabled      => "true",
      :items => [
        {
          :button       => "configured_system_provision",
          :icon         => "pficon pficon-add-circle-o fa-lg",
          :text         => N_("Provision Configured System"),
          :title        => N_("Provision Configured System"),
          :url          => "provision",
          :url_parms    => "main_div",
          :enabled      => "true",
        },
      ]
    },
    {
      :buttonSelect => "provider_foreman_policy_choice",
      :icon         => "fa fa-shield fa-lg",
      :title        => N_("Policy"),
      :text         => N_("Policy"),
      :enabled      => "true",
      :items => [
        {
          :button       => "configured_system_tag",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Tags"),
          :title        => N_("Edit Tags for this Configured System"),
          :url          => "tagging",
          :url_parms    => "main_div",
          :enabled      => "true",
        },
      ]
    },
  ])
end
