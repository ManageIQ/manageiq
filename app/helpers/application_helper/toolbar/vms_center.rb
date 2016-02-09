class ApplicationHelper::Toolbar::VmsCenter < ApplicationHelper::Toolbar::Basic
  button_group('vm_vmdb', [
    {
      :buttonSelect => "vm_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :enabled      => "false",
      :onwhen       => "1+",
      :items => [
        {
          :button       => "vm_refresh",
          :icon         => "fa fa-refresh fa-lg",
          :text         => N_("Refresh Relationships and Power States"),
          :title        => N_("Refresh relationships and power states for all items related to the selected items"),
          :url_parms    => "main_div",
          :confirm      => N_("Refresh relationships and power states for all items related to the selected items?"),
          :enabled      => "false",
          :onwhen       => "1+",
        },
        {
          :button       => "vm_compare",
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
          :button       => "vm_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Selected item"),
          :title        => N_("Select a single item to edit"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1",
        },
        {
          :button       => "vm_ownership",
          :icon         => "pficon pficon-user fa-lg",
          :text         => N_("Set Ownership"),
          :title        => N_("Set Ownership for the selected items"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1+",
        },
        {
          :button       => "vm_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove selected items from the VMDB"),
          :title        => N_("Remove selected items from the VMDB"),
          :url_parms    => "main_div",
          :confirm      => N_("Warning: The selected items and ALL of their components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove the selected items?"),
          :enabled      => "false",
          :onwhen       => "1+",
        },
        {
          :separator    => nil,
        },
      ]
    },
  ])
  button_group('vm_policy', [
    {
      :buttonSelect => "vm_policy_choice",
      :icon         => "fa fa-shield fa-lg",
      :title        => N_("Policy"),
      :text         => N_("Policy"),
      :enabled      => "false",
      :onwhen       => "1+",
      :items => [
        {
          :button       => "vm_protect",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Manage Policies"),
          :title        => N_("Manage Policies for the selected items"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1+",
        },
        {
          :button       => "vm_policy_sim",
          :icon         => "fa fa-play-circle-o fa-lg",
          :text         => N_("Policy Simulation"),
          :title        => N_("View Policy Simulation for the selected items"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1+",
        },
        {
          :button       => "vm_tag",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Tags"),
          :title        => N_("Edit tags for the selected items"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1+",
        },
        {
          :button       => "vm_check_compliance",
          :icon         => "fa fa-search fa-lg",
          :text         => N_("Check Compliance of Last Known Configuration"),
          :title        => N_("Check Compliance of the last known configuration for the selected items"),
          :url_parms    => "main_div",
          :confirm      => N_("Initiate Check Compliance of the last known configuration for the selected items?"),
          :enabled      => "false",
          :onwhen       => "1+",
        },
      ]
    },
  ])
  button_group('vm_lifecycle', [
    {
      :buttonSelect => "vm_lifecycle_choice",
      :icon         => "fa fa-recycle fa-lg",
      :title        => N_("Lifecycle"),
      :text         => N_("Lifecycle"),
      :items => [
        {
          :button       => "vm_miq_request_new",
          :icon         => "pficon pficon-add-circle-o fa-lg",
          :url_parms    => "main_div",
          :text         => N_("Provision"),
          :title        => N_("Request to Provision"),
        },
      ]
    },
  ])
end
