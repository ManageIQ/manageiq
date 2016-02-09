class ApplicationHelper::Toolbar::OntapStorageVolumeCenter < ApplicationHelper::Toolbar::Basic
  button_group('ontap_storage_volume_policy', [
    {
      :buttonSelect => "ontap_storage_volume_policy_choice",
      :icon         => "fa fa-shield fa-lg",
      :title        => N_("Policy"),
      :text         => N_("Policy"),
      :items => [
        {
          :button       => "ontap_storage_volume_tag",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Tags"),
          :title        => N_("Edit Tags for this Volume"),
        },
      ]
    },
  ])
  button_group('ontap_storage_volume_monitoring', [
    {
      :buttonSelect => "ontap_storage_volume_monitoring_choice",
      :icon         => "product product-monitoring fa-lg",
      :title        => N_("Monitoring"),
      :text         => N_("Monitoring"),
      :items => [
        {
          :button       => "ontap_storage_volume_statistics",
          :icon         => "product product-monitoring fa-lg",
          :text         => N_("Utilization"),
          :title        => N_("Show Utilization for this Storage System"),
          :url          => "/show_statistics",
        },
      ]
    },
  ])
end
