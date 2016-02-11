class ApplicationHelper::Toolbar::VmsCenter < ApplicationHelper::Toolbar::Basic
  button_group('vm_vmdb', [
    select(
      :vm_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :enabled => "false",
      :onwhen  => "1+",
      :items   => [
        button(
          :vm_refresh,
          'fa fa-refresh fa-lg',
          N_('Refresh relationships and power states for all items related to the selected items'),
          N_('Refresh Relationships and Power States'),
          :url_parms => "main_div",
          :confirm   => N_("Refresh relationships and power states for all items related to the selected items?"),
          :enabled   => "false",
          :onwhen    => "1+"),
        button(
          :vm_compare,
          'product product-compare fa-lg',
          N_('Select two or more items to compare'),
          N_('Compare Selected items'),
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "2+"),
        separator,
        button(
          :vm_edit,
          'pficon pficon-edit fa-lg',
          N_('Select a single item to edit'),
          N_('Edit Selected item'),
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "1"),
        button(
          :vm_ownership,
          'pficon pficon-user fa-lg',
          N_('Set Ownership for the selected items'),
          N_('Set Ownership'),
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "1+"),
        button(
          :vm_delete,
          'pficon pficon-delete fa-lg',
          t = N_('Remove selected items from the VMDB'),
          t,
          :url_parms => "main_div",
          :confirm   => N_("Warning: The selected items and ALL of their components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove the selected items?"),
          :enabled   => "false",
          :onwhen    => "1+"),
        separator,
      ]
    ),
  ])
  button_group('vm_policy', [
    select(
      :vm_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :enabled => "false",
      :onwhen  => "1+",
      :items   => [
        button(
          :vm_protect,
          'pficon pficon-edit fa-lg',
          N_('Manage Policies for the selected items'),
          N_('Manage Policies'),
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "1+"),
        button(
          :vm_policy_sim,
          'fa fa-play-circle-o fa-lg',
          N_('View Policy Simulation for the selected items'),
          N_('Policy Simulation'),
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "1+"),
        button(
          :vm_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit tags for the selected items'),
          N_('Edit Tags'),
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "1+"),
        button(
          :vm_check_compliance,
          'fa fa-search fa-lg',
          N_('Check Compliance of the last known configuration for the selected items'),
          N_('Check Compliance of Last Known Configuration'),
          :url_parms => "main_div",
          :confirm   => N_("Initiate Check Compliance of the last known configuration for the selected items?"),
          :enabled   => "false",
          :onwhen    => "1+"),
      ]
    ),
  ])
  button_group('vm_lifecycle', [
    select(
      :vm_lifecycle_choice,
      'fa fa-recycle fa-lg',
      t = N_('Lifecycle'),
      t,
      :items => [
        button(
          :vm_miq_request_new,
          'pficon pficon-add-circle-o fa-lg',
          N_('Request to Provision'),
          N_('Provision'),
          :url_parms => "main_div"),
      ]
    ),
  ])
end
