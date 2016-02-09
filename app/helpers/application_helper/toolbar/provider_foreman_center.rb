class ApplicationHelper::Toolbar::ProviderForemanCenter < ApplicationHelper::Toolbar::Basic
  button_group('provider_vmdb', [
    {
      :buttonSelect => "provider_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :enabled      => "true",
      :items => [
        {
          :button       => "provider_foreman_refresh_provider",
          :icon         => "fa fa-refresh fa-lg",
          :text         => N_("Refresh Relationships and Power states"),
          :title        => N_("Refresh relationships for all items related to the selected items"),
          :url          => "refresh",
          :url_parms    => "main_div",
          :confirm      => N_("Refresh relationships for all items related to the selected items?"),
          :enabled      => "false",
          :onwhen       => "1+",
        },
        {
          :separator    => nil,
        },
        {
          :button       => "provider_foreman_add_provider",
          :icon         => "pficon pficon-add-circle-o fa-lg",
          :text         => N_("Add a new Provider"),
          :title        => N_("Add a new Provider"),
          :enabled      => "true",
          :url          => "new",
        },
        {
          :button       => "provider_foreman_edit_provider",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Selected item"),
          :title        => N_("Select a single item to edit"),
          :url          => "edit",
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1",
        },
        {
          :button       => "provider_foreman_delete_provider",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove selected items from the VMDB"),
          :title        => N_("Remove selected items from the VMDB"),
          :url          => "delete",
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
end
