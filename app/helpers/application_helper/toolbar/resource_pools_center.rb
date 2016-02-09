class ApplicationHelper::Toolbar::ResourcePoolsCenter < ApplicationHelper::Toolbar::Basic
  button_group('resource_pool_vmdb', [
    {
      :buttonSelect => "resource_pool_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :enabled      => "false",
      :onwhen       => "1+",
      :items => [
        {
          :button       => "resource_pool_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove Resource Pools from the VMDB"),
          :title        => N_("Remove selected Resource Pools from the VMDB"),
          :url_parms    => "main_div",
          :confirm      => N_("Warning: The selected Resource Pools and ALL of their components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove the selected Resource Pools?"),
          :enabled      => "false",
          :onwhen       => "1+",
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
      :enabled      => "false",
      :onwhen       => "1+",
      :items => [
        {
          :button       => "resource_pool_protect",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Manage Policies"),
          :title        => N_("Manage Policies for the selected Resource Pools"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1+",
        },
        {
          :button       => "resource_pool_tag",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Tags"),
          :title        => N_("Edit Tags for the selected Resource Pools"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1+",
        },
      ]
    },
  ])
end
