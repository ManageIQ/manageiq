class ApplicationHelper::Toolbar::ConfiguredSystemsForemanCenter < ApplicationHelper::Toolbar::Basic
  button_group('provider_foreman_lifecycle', [
    {
      :buttonSelect => "provider_foreman_lifecycle_choice",
      :icon         => "fa fa-recycle fa-lg",
      :title        => N_("Lifecycle"),
      :text         => N_("Lifecycle"),
      :enabled      => "true",
      :items => [
        {
          :button       => "provider_foreman_configured_system_provision",
          :icon         => "pficon pficon-add-circle-o fa-lg",
          :text         => N_("Provision Configured Systems"),
          :title        => N_("Provision Configured Systems"),
          :url          => "provision",
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1+",
        },
      ]
    },
  ])
  button_group('provider_foreman_policy', [
    {
      :buttonSelect => "provider_foreman_policy_choice",
      :icon         => "fa fa-shield fa-lg",
      :title        => N_("Policy"),
      :text         => N_("Policy"),
      :items => [
        {
          :button       => "provider_foreman_configured_system_tag",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Tags"),
          :title        => N_("Edit Tags for this Configured System"),
          :url          => "tagging",
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1+",
        },
      ]
    },
  ])
end
