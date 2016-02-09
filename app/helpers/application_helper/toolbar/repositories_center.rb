class ApplicationHelper::Toolbar::RepositoriesCenter < ApplicationHelper::Toolbar::Basic
  button_group('repository_vmdb', [
    {
      :buttonSelect => "repository_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "repository_refresh",
          :icon         => "fa fa-refresh fa-lg",
          :text         => N_("Refresh Relationships and Power States"),
          :title        => N_("Refresh Relationships and Power States for all items related to the selected Repositories"),
          :url_parms    => "main_div",
          :confirm      => N_("Refresh relationships and power states for all items related to the selected Repositories?"),
          :enabled      => "false",
          :onwhen       => "1+",
        },
        {
          :separator    => nil,
        },
        {
          :button       => "repository_new",
          :icon         => "pficon pficon-add-circle-o fa-lg",
          :url          => "/new",
          :text         => N_("Add a new Repository"),
          :title        => N_("Add a new Repository"),
        },
        {
          :button       => "repository_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit the Selected Repository"),
          :title        => N_("Select a single Repository to edit"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1",
        },
        {
          :button       => "repository_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove Repositories from the VMDB"),
          :title        => N_("Remove Selected Repositories from the VMDB"),
          :url_parms    => "main_div",
          :confirm      => N_("Warning: The selected Repositories and ALL of their components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove the selected Repositories?"),
          :enabled      => "false",
          :onwhen       => "1+",
        },
      ]
    },
  ])
  button_group('repository_policy', [
    {
      :buttonSelect => "repository_policy_choice",
      :icon         => "fa fa-shield fa-lg",
      :title        => N_("Policy"),
      :text         => N_("Policy"),
      :enabled      => "false",
      :onwhen       => "1+",
      :items => [
        {
          :button       => "repository_protect",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Manage Policies"),
          :title        => N_("Manage Policies for the selected Repositories"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1+",
        },
        {
          :button       => "repository_tag",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Tags"),
          :title        => N_("Edit Tags for the selected Repositories"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1+",
        },
      ]
    },
  ])
end
