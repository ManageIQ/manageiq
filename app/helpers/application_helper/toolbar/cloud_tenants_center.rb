class ApplicationHelper::Toolbar::CloudTenantsCenter < ApplicationHelper::Toolbar::Basic
  button_group('cloud_tenant_policy', [
    {
      :buttonSelect => "cloud_tenant_policy_choice",
      :icon         => "fa fa-shield fa-lg",
      :title        => N_("Policy"),
      :text         => N_("Policy"),
      :items => [
        {
          :button       => "cloud_tenant_tag",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Tags"),
          :title        => N_("Edit tags for the selected items"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1+",
        },
      ]
    },
  ])
end
