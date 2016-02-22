class ApplicationHelper::Toolbar::EmsClustersCenter < ApplicationHelper::Toolbar::Basic
  button_group('ems_cluster_vmdb', [
    select(
      :ems_cluster_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :enabled => "false",
      :onwhen  => "1+",
      :items   => [
        button(
          :ems_cluster_scan,
          'fa fa-search fa-lg',
          N_('Perform SmartState Analysis on the selected items'),
          N_('Perform SmartState Analysis'),
          :url_parms => "main_div",
          :confirm   => N_("Perform SmartState Analysis on the selected items?"),
          :enabled   => "false",
          :onwhen    => "1+"),
        button(
          :ems_cluster_compare,
          'product product-compare fa-lg',
          N_('Select two or more items to compare'),
          N_('Compare Selected items'),
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "2+"),
        separator,
        button(
          :ems_cluster_delete,
          'pficon pficon-delete fa-lg',
          t = N_('Remove selected items from the VMDB'),
          t,
          :url_parms => "main_div",
          :confirm   => N_("Warning: The selected items and ALL of their components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove the selected items?"),
          :enabled   => "false",
          :onwhen    => "1+"),
      ]
    ),
  ])
  button_group('ems_cluster_policy', [
    select(
      :ems_cluster_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :enabled => "false",
      :onwhen  => "1+",
      :items   => [
        button(
          :ems_cluster_protect,
          'pficon pficon-edit fa-lg',
          N_('Manage Policies for the selected items'),
          N_('Manage Policies'),
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "1+"),
        button(
          :ems_cluster_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for the selected items'),
          N_('Edit Tags'),
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "1+"),
      ]
    ),
  ])
end
