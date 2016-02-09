class ApplicationHelper::Toolbar::ProviderForemanCenter < ApplicationHelper::Toolbar::Basic
  button_group('provider_vmdb', [
    select(:provider_vmdb_choice, 'fa fa-cog fa-lg', N_('Configuration'), N_('Configuration'),
      :enabled   => "true",
      :items     => [
        button(:provider_foreman_refresh_provider, 'fa fa-refresh fa-lg', N_('Refresh relationships for all items related to the selected items'), N_('Refresh Relationships and Power states'),
          :url       => "refresh",
          :url_parms => "main_div",
          :confirm   => N_("Refresh relationships for all items related to the selected items?"),
          :enabled   => "false",
          :onwhen    => "1+"),
        separator,
        button(:provider_foreman_add_provider, 'pficon pficon-add-circle-o fa-lg', N_('Add a new Provider'), N_('Add a new Provider'),
          :enabled   => "true",
          :url       => "new"),
        button(:provider_foreman_edit_provider, 'pficon pficon-edit fa-lg', N_('Select a single item to edit'), N_('Edit Selected item'),
          :url       => "edit",
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "1"),
        button(:provider_foreman_delete_provider, 'pficon pficon-delete fa-lg', N_('Remove selected items from the VMDB'), N_('Remove selected items from the VMDB'),
          :url       => "delete",
          :url_parms => "main_div",
          :confirm   => N_("Warning: The selected items and ALL of their components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove the selected items?"),
          :enabled   => "false",
          :onwhen    => "1+"),
        separator,
      ]
    ),
  ])
end
