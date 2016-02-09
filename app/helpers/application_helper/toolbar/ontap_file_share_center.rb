class ApplicationHelper::Toolbar::OntapFileShareCenter < ApplicationHelper::Toolbar::Basic
  button_group('ontap_file_share_vmdb', [
    {
      :buttonSelect => "ontap_file_share_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "ontap_file_share_create_datastore",
          :icon         => "pficon pficon-add-circle-o fa-lg",
          :text         => N_("Create Datastore"),
          :title        => N_("Create a Datastore based on this \#{ui_lookup(:model=>\"OntapFileShare\").split(\" - \").last}"),
        },
      ]
    },
  ])
  button_group('ontap_file_share_policy', [
    {
      :buttonSelect => "ontap_file_share_policy_choice",
      :icon         => "fa fa-shield fa-lg",
      :title        => N_("Policy"),
      :text         => N_("Policy"),
      :items => [
        {
          :button       => "ontap_file_share_tag",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Tags"),
          :title        => N_("Edit Tags for this \#{ui_lookup(:model=>\"OntapFileShare\").split(\" - \").last}"),
        },
      ]
    },
  ])
  button_group('ontap_file_share_monitoring', [
    {
      :buttonSelect => "ontap_file_share_monitoring_choice",
      :icon         => "product product-monitoring fa-lg",
      :title        => N_("Monitoring"),
      :text         => N_("Monitoring"),
      :items => [
        {
          :button       => "ontap_file_share_statistics",
          :icon         => "product product-monitoring fa-lg",
          :text         => N_("Utilization"),
          :title        => N_("Show Utilization for this \#{ui_lookup(:model=>\"OntapFileShare\").split(\" - \").last}"),
          :url          => "/show_statistics",
        },
      ]
    },
  ])
end
