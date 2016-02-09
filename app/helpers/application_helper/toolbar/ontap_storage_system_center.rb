class ApplicationHelper::Toolbar::OntapStorageSystemCenter < ApplicationHelper::Toolbar::Basic
  button_group('ontap_storage_system_vmdb', [
    {
      :buttonSelect => "ontap_storage_system_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "ontap_storage_system_create_logical_disk",
          :icon         => "pficon pficon-add-circle-o fa-lg",
          :text         => N_("Create Logical Disk"),
          :title        => N_("Create a Logical Disk (NetApp Flexible Volume) on this \#{ui_lookup(:model=>\"OntapStorageSystem\").split(\" - \").last}"),
        },
      ]
    },
  ])
  button_group('ontap_storage_system_policy', [
    {
      :buttonSelect => "ontap_storage_system_policy_choice",
      :icon         => "fa fa-shield fa-lg",
      :title        => N_("Policy"),
      :text         => N_("Policy"),
      :items => [
        {
          :button       => "ontap_storage_system_tag",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Tags"),
          :title        => N_("Edit Tags for this \#{ui_lookup(:model=>\"OntapStorageSystem\").split(\" - \").last}"),
        },
      ]
    },
  ])
  button_group('ontap_storage_system_monitoring', [
    {
      :buttonSelect => "ontap_storage_system_monitoring_choice",
      :icon         => "product product-monitoring fa-lg",
      :title        => N_("Monitoring"),
      :text         => N_("Monitoring"),
      :items => [
        {
          :button       => "ontap_storage_system_statistics",
          :icon         => "product product-monitoring fa-lg",
          :text         => N_("Utilization"),
          :title        => N_("Show Utilization for this \#{ui_lookup(:model=>\"OntapStorageSystem\").split(\" - \").last}"),
          :url          => "/show_statistics",
        },
      ]
    },
  ])
end
