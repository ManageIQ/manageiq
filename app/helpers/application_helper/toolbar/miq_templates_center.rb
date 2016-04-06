class ApplicationHelper::Toolbar::MiqTemplatesCenter < ApplicationHelper::Toolbar::Basic
  button_group('miq_template_vmdb', [
    select(
      :miq_template_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :enabled => false,
      :onwhen  => "1+",
      :items   => [
        button(
          :miq_template_refresh,
          'fa fa-refresh fa-lg',
          N_('Refresh relationships and power states for all items related to the selected Templates'),
          N_('Refresh Relationships and Power States'),
          :url_parms => "main_div",
          :confirm   => N_("Refresh relationships and power states for all items related to the selected Templates?"),
          :enabled   => false,
          :onwhen    => "1+"),
        button(
          :miq_template_compare,
          'product product-compare fa-lg',
          N_('Select two or more Templates to compare'),
          N_('Compare Selected Templates'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "2+"),
        separator,
        button(
          :miq_template_edit,
          'pficon pficon-edit fa-lg',
          N_('Select a single Template to edit'),
          N_('Edit Selected Template'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1"),
        button(
          :miq_template_ownership,
          'pficon pficon-user fa-lg',
          N_('Set Ownership for the selected Templates'),
          N_('Set Ownership'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1+"),
        button(
          :miq_template_delete,
          'pficon pficon-delete fa-lg',
          N_('Remove selected Templates from the VMDB'),
          N_('Remove Templates from the VMDB'),
          :url_parms => "main_div",
          :confirm   => N_("Warning: The selected Templates and ALL of their components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove the selected Templates?"),
          :enabled   => false,
          :onwhen    => "1+"),
      ]
    ),
  ])
  button_group('miq_template_policy', [
    select(
      :miq_template_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :enabled => false,
      :onwhen  => "1+",
      :items   => [
        button(
          :miq_template_protect,
          'pficon pficon-edit fa-lg',
          N_('Manage Policies for the selected Templates'),
          N_('Manage Policies'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1+"),
        button(
          :miq_template_policy_sim,
          'fa fa-play-circle-o fa-lg',
          N_('View Policy Simulation for the selected Templates'),
          N_('Policy Simulation'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1+"),
        button(
          :miq_template_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit tags for the selected Templates'),
          N_('Edit Tags'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1+"),
        button(
          :miq_template_check_compliance,
          'fa fa-search fa-lg',
          N_('Check Compliance of the last known configuration for the selected Templates'),
          N_('Check Compliance of Last Known Configuration'),
          :url_parms => "main_div",
          :confirm   => N_("Initiate Check Compliance of the last known configuration for the selected Templates?"),
          :enabled   => false,
          :onwhen    => "1+"),
      ]
    ),
  ])
end
