class ApplicationHelper::Toolbar::MiqTemplatesCenter < ApplicationHelper::Toolbar::Basic
  button_group('miq_template_vmdb', [
    {
      :buttonSelect => "miq_template_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :enabled      => "false",
      :onwhen       => "1+",
      :items => [
        {
          :button       => "miq_template_refresh",
          :icon         => "fa fa-refresh fa-lg",
          :text         => N_("Refresh Relationships and Power States"),
          :title        => N_("Refresh relationships and power states for all items related to the selected Templates"),
          :url_parms    => "main_div",
          :confirm      => N_("Refresh relationships and power states for all items related to the selected Templates?"),
          :enabled      => "false",
          :onwhen       => "1+",
        },
        {
          :button       => "miq_template_compare",
          :icon         => "product product-compare fa-lg",
          :text         => N_("Compare Selected Templates"),
          :title        => N_("Select two or more Templates to compare"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "2+",
        },
        {
          :separator    => nil,
        },
        {
          :button       => "miq_template_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Selected Template"),
          :title        => N_("Select a single Template to edit"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1",
        },
        {
          :button       => "miq_template_ownership",
          :icon         => "pficon pficon-user fa-lg",
          :text         => N_("Set Ownership"),
          :title        => N_("Set Ownership for the selected Templates"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1+",
        },
        {
          :button       => "miq_template_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove Templates from the VMDB"),
          :title        => N_("Remove selected Templates from the VMDB"),
          :url_parms    => "main_div",
          :confirm      => N_("Warning: The selected Templates and ALL of their components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove the selected Templates?"),
          :enabled      => "false",
          :onwhen       => "1+",
        },
      ]
    },
  ])
  button_group('miq_template_policy', [
    {
      :buttonSelect => "miq_template_policy_choice",
      :icon         => "fa fa-shield fa-lg",
      :title        => N_("Policy"),
      :text         => N_("Policy"),
      :enabled      => "false",
      :onwhen       => "1+",
      :items => [
        {
          :button       => "miq_template_protect",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Manage Policies"),
          :title        => N_("Manage Policies for the selected Templates"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1+",
        },
        {
          :button       => "miq_template_policy_sim",
          :icon         => "fa fa-play-circle-o fa-lg",
          :text         => N_("Policy Simulation"),
          :title        => N_("View Policy Simulation for the selected Templates"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1+",
        },
        {
          :button       => "miq_template_tag",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Tags"),
          :title        => N_("Edit tags for the selected Templates"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1+",
        },
        {
          :button       => "miq_template_check_compliance",
          :icon         => "fa fa-search fa-lg",
          :text         => N_("Check Compliance of Last Known Configuration"),
          :title        => N_("Check Compliance of the last known configuration for the selected Templates"),
          :url_parms    => "main_div",
          :confirm      => N_("Initiate Check Compliance of the last known configuration for the selected Templates?"),
          :enabled      => "false",
          :onwhen       => "1+",
        },
      ]
    },
  ])
end
