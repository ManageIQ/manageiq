class ApplicationHelper::Toolbar::OntapStorageSystemsCenter < ApplicationHelper::Toolbar::Basic
  button_group('ontap_storage_system_policy', [
    {
      :buttonSelect => "ontap_storage_system_policy_choice",
      :icon         => "fa fa-shield fa-lg",
      :title        => N_("Policy"),
      :text         => N_("Policy"),
      :enabled      => "false",
      :onwhen       => "1+",
      :items => [
        {
          :button       => "ontap_storage_system_tag",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Tags"),
          :title        => N_("Edit tags for the selected Systems"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1+",
        },
      ]
    },
  ])
end
