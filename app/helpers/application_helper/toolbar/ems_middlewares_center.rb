class ApplicationHelper::Toolbar::EmsMiddlewaresCenter < ApplicationHelper::Toolbar::Basic
  button_group('ems_middleware_vmdb', [
    select(
      :ems_middleware_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :ems_middleware_new,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Add a New Middleware Provider'),
          t,
          :url => "/new"),
        button(
          :ems_middleware_edit,
          'pficon pficon-edit fa-lg',
          N_('Select a single Middleware Providers to edit'),
          N_('Edit Selected Middleware Providers'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1"),
        button(
          :ems_middleware_delete,
          'pficon pficon-delete fa-lg',
          N_('Remove selected Middleware Providers from the VMDB'),
          N_('Remove Middleware Providers from the VMDB'),
          :url_parms => "main_div",
          :confirm   => N_("Warning: The selected Middleware Providers and ALL of their components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove the selected Middleware Providers?"),
          :enabled   => false,
          :onwhen    => "1+"),
      ]
    ),
  ])
  button_group('ems_middleware_policy', [
    select(
      :ems_middleware_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :enabled => false,
      :onwhen  => "1+",
      :items   => [
        button(
          :ems_middleware_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for these Middleware Providers'),
          N_('Edit Tags'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1+"),
      ]
    ),
  ])
end
