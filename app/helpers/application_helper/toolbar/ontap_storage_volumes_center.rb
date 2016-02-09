class ApplicationHelper::Toolbar::OntapStorageVolumesCenter < ApplicationHelper::Toolbar::Basic
  button_group('ontap_storage_volume_policy', [
    {
      :buttonSelect => "ontap_storage_volume_policy_choice",
      :icon         => "fa fa-shield fa-lg",
      :title        => N_("Policy"),
      :text         => N_("Policy"),
      :enabled      => "false",
      :onwhen       => "1+",
      :items => [
        {
          :button       => "ontap_storage_volume_tag",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Tags"),
          :title        => N_("Edit tags for the selected Volumes"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1+",
        },
      ]
    },
  ])
end
