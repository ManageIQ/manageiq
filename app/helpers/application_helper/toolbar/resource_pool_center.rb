class ApplicationHelper::Toolbar::ResourcePoolCenter < ApplicationHelper::Toolbar::Basic
  button_group('resource_pool_vmdb', [
    {
      :buttonSelect => "resource_pool_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "resource_pool_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove from the VMDB"),
          :title        => N_("Remove this Resource Pool from the VMDB"),
          :url_parms    => "&refresh=y",
          :confirm      => N_("Warning: This Resource Pool and ALL of its components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this Resource Pool?"),
        },
      ]
    },
  ])
  button_group('resource_pool_policy', [
    {
      :buttonSelect => "resource_pool_policy_choice",
      :icon         => "fa fa-shield fa-lg",
      :title        => N_("Policy"),
      :text         => N_("Policy"),
      :items => [
        {
          :button       => "resource_pool_protect",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Manage Policies"),
          :title        => N_("Manage Policies for this Resource Pool"),
        },
        {
          :button       => "resource_pool_tag",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Tags"),
          :title        => N_("Edit Tags for this Resource Pool"),
        },
      ]
    },
  ])
end
