class ApplicationHelper::Toolbar::XTemplateCloudCenter < ApplicationHelper::Toolbar::Basic
  button_group('image_vmdb', [
    {
      :buttonSelect => "image_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "image_refresh",
          :icon         => "fa fa-refresh fa-lg",
          :text         => N_("Refresh Relationships and Power States"),
          :title        => N_("Refresh relationships and power states for all items related to this Image"),
          :confirm      => N_("Refresh relationships and power states for all items related to this Image?"),
        },
        {
          :button       => "image_scan",
          :icon         => "fa fa-search fa-lg",
          :text         => N_("Perform SmartState Analysis"),
          :title        => N_("Perform SmartState Analysis on this Image"),
          :confirm      => N_("Perform SmartState Analysis on this Image?"),
        },
        {
          :separator    => nil,
        },
        {
          :button       => "image_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit this Image"),
          :title        => N_("Edit this Image"),
        },
        {
          :button       => "image_ownership",
          :icon         => "pficon pficon-user fa-lg",
          :text         => N_("Set Ownership"),
          :title        => N_("Set Ownership for this Image"),
        },
        {
          :button       => "image_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove from the VMDB"),
          :title        => N_("Remove this Image from the VMDB"),
          :url_parms    => "&refresh=y",
          :confirm      => N_("Warning: This Image and ALL of its components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this Image?"),
        },
        {
          :separator    => nil,
        },
        {
          :button       => "image_right_size",
          :icon         => "product product-custom-6 fa-lg",
          :text         => N_("Right-Size Recommendations"),
          :title        => N_("CPU/Memory Recommendations of this Image"),
        },
        {
          :button       => "image_reconfigure",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Reconfigure this Image"),
          :title        => N_("Reconfigure the Memory/CPU of this Image"),
        },
      ]
    },
  ])
  button_group('image_policy', [
    {
      :buttonSelect => "image_policy_choice",
      :icon         => "fa fa-shield fa-lg",
      :title        => N_("Policy"),
      :text         => N_("Policy"),
      :items => [
        {
          :button       => "image_protect",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Manage Policies"),
          :title        => N_("Manage Policies for this Image"),
        },
        {
          :button       => "image_policy_sim",
          :icon         => "fa fa-play-circle-o fa-lg",
          :text         => N_("Policy Simulation"),
          :title        => N_("View Policy Simulation for this Image"),
        },
        {
          :button       => "image_tag",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Tags"),
          :title        => N_("Edit Tags for this Image"),
        },
        {
          :button       => "image_check_compliance",
          :icon         => "fa fa-search fa-lg",
          :text         => N_("Check Compliance of Last Known Configuration"),
          :title        => N_("Check Compliance of the last known configuration for this Image"),
          :confirm      => N_("Initiate Check Compliance of the last known configuration for this Image?"),
        },
      ]
    },
  ])
end
