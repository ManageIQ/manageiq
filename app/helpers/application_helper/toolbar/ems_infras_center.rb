class ApplicationHelper::Toolbar::EmsInfrasCenter < ApplicationHelper::Toolbar::Basic
  button_group('ems_infra_vmdb', [
    {
      :buttonSelect => "ems_infra_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "ems_infra_refresh",
          :icon         => "fa fa-refresh fa-lg",
          :text         => N_("Refresh Relationships and Power States"),
          :title        => N_("Refresh relationships and power states for all items related to the selected \#{ui_lookup(:tables=>\"ems_infras\")}"),
          :url_parms    => "main_div",
          :confirm      => N_("Refresh relationships and power states for all items related to the selected \#{ui_lookup(:tables=>\"ems_infras\")}?"),
          :enabled      => "false",
          :onwhen       => "1+",
        },
        {
          :button       => "ems_infra_discover",
          :icon         => "fa fa-search fa-lg",
          :text         => N_("Discover \#{ui_lookup(:tables=>\"ems_infras\")}"),
          :title        => N_("Discover \#{ui_lookup(:tables=>\"ems_infras\")}"),
          :url          => "/discover",
          :url_parms    => "?discover_type=ems",
        },
        {
          :separator    => nil,
        },
        {
          :button       => "ems_infra_new",
          :icon         => "pficon pficon-add-circle-o fa-lg",
          :url          => "/new",
          :text         => N_("Add a New \#{ui_lookup(:table=>\"ems_infra\")}"),
          :title        => N_("Add a New \#{ui_lookup(:table=>\"ems_infra\")}"),
        },
        {
          :button       => "ems_infra_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Selected \#{ui_lookup(:table=>\"ems_infra\")}"),
          :title        => N_("Select a single \#{ui_lookup(:table=>\"ems_infra\")} to edit"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1",
        },
        {
          :button       => "ems_infra_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove \#{ui_lookup(:tables=>\"ems_infras\")} from the VMDB"),
          :title        => N_("Remove selected \#{ui_lookup(:tables=>\"ems_infras\")} from the VMDB"),
          :url_parms    => "main_div",
          :confirm      => N_("Warning: The selected \#{ui_lookup(:tables=>\"ems_infras\")} and ALL of their components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove the selected \#{ui_lookup(:tables=>\"ems_infras\")}?"),
          :enabled      => "false",
          :onwhen       => "1+",
        },
      ]
    },
  ])
  button_group('ems_infra_policy', [
    {
      :buttonSelect => "ems_infra_policy_choice",
      :icon         => "fa fa-shield fa-lg",
      :title        => N_("Policy"),
      :text         => N_("Policy"),
      :enabled      => "false",
      :onwhen       => "1+",
      :items => [
        {
          :button       => "ems_infra_protect",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Manage Policies"),
          :title        => N_("Manage Policies for the selected \#{ui_lookup(:tables=>\"ems_infras\")}"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1+",
        },
        {
          :button       => "ems_infra_tag",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Tags"),
          :title        => N_("Edit Tags for the selected \#{ui_lookup(:tables=>\"ems_infras\")}"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1+",
        },
      ]
    },
  ])
end
