class ApplicationHelper::Toolbar::EmsClustersCenter < ApplicationHelper::Toolbar::Basic
  button_group('ems_cluster_vmdb', [
    {
      :buttonSelect => "ems_cluster_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :enabled      => "false",
      :onwhen       => "1+",
      :items => [
        {
          :button       => "ems_cluster_scan",
          :icon         => "fa fa-search fa-lg",
          :text         => N_("Perform SmartState Analysis"),
          :title        => N_("Perform SmartState Analysis on the selected items"),
          :url_parms    => "main_div",
          :confirm      => N_("Perform SmartState Analysis on the selected items?"),
          :enabled      => "false",
          :onwhen       => "1+",
        },
        {
          :button       => "ems_cluster_compare",
          :icon         => "product product-compare fa-lg",
          :text         => N_("Compare Selected items"),
          :title        => N_("Select two or more items to compare"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "2+",
        },
        {
          :separator    => nil,
        },
        {
          :button       => "ems_cluster_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove selected items from the VMDB"),
          :title        => N_("Remove selected items from the VMDB"),
          :url_parms    => "main_div",
          :confirm      => N_("Warning: The selected items and ALL of their components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove the selected items?"),
          :enabled      => "false",
          :onwhen       => "1+",
        },
      ]
    },
  ])
  button_group('ems_cluster_policy', [
    {
      :buttonSelect => "ems_cluster_policy_choice",
      :icon         => "fa fa-shield fa-lg",
      :title        => N_("Policy"),
      :text         => N_("Policy"),
      :enabled      => "false",
      :onwhen       => "1+",
      :items => [
        {
          :button       => "ems_cluster_protect",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Manage Policies"),
          :title        => N_("Manage Policies for the selected items"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1+",
        },
        {
          :button       => "ems_cluster_tag",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Tags"),
          :title        => N_("Edit Tags for the selected items"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1+",
        },
      ]
    },
  ])
end
