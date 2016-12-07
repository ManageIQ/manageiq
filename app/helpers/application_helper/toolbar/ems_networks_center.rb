class ApplicationHelper::Toolbar::EmsNetworksCenter < ApplicationHelper::Toolbar::Basic
  button_group('ems_network_vmdb', [
    select(
      :ems_network_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :ems_network_refresh,
          'fa fa-refresh fa-lg',
          N_('Refresh relationships and power states for all items related to the selected Network Providers'),
          N_('Refresh Relationships and Power States'),
          :url_parms => "main_div",
          :confirm   => N_("Refresh relationships and power states for all items related to the selected Network Providers?"),
          :enabled   => false,
          :onwhen    => "1+"),
        separator,
        button(
          :ems_network_new,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Add a New Network Provider'),
          t,
          :url   => "/new",
          :klass => ApplicationHelper::Button::EmsNetwork),
        button(
          :ems_network_edit,
          'pficon pficon-edit fa-lg',
          N_('Select a single Network Provider to edit'),
          N_('Edit Selected Network Provider'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1",
          :klass     => ApplicationHelper::Button::EmsNetwork),
        button(
          :ems_network_delete,
          'pficon pficon-delete fa-lg',
          N_('Remove selected Network Providers'),
          N_('Remove Network Providers'),
          :url_parms => "main_div",
          :confirm   => N_("Warning: The selected Network Providers and ALL of their components will be permanently removed!"),
          :enabled   => false,
          :onwhen    => "1+"),
      ]
    ),
  ])
  button_group('ems_network_policy', [
    select(
      :ems_network_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :enabled => false,
      :onwhen  => "1+",
      :items   => [
        button(
          :ems_network_protect,
          'pficon pficon-edit fa-lg',
          N_('Manage Policies for the selected Network Providers'),
          N_('Manage Policies'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1+"),
        button(
          :ems_network_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for the selected Network Providers'),
          N_('Edit Tags'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1+"),
      ]
    ),
  ])
end
