class ApplicationHelper::Toolbar::ConfigurationProfileForemanCenter < ApplicationHelper::Toolbar::Basic
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
          :title        => N_("Refresh relationships for all items related to this Provider"),
          :url          => "refresh",
          :confirm      => N_("Refresh relationships for all items related to this Provider?"),
        },
        {
          :separator    => nil,
        },
        {
          :button       => "provider_foreman_edit_provider",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit this Provider"),
          :title        => N_("Edit this Provider"),
          :url          => "edit",
        },
        {
          :button       => "provider_foreman_delete_provider",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove this Provider from the VMDB"),
          :title        => N_("Remove this Provider from the VMDB"),
          :url          => "delete",
          :confirm      => N_("Warning: The selected Provider and ALL of their components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this Provider?"),
        },
      ]
    },
  ])
end
