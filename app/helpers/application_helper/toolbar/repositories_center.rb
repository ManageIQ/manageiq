class ApplicationHelper::Toolbar::RepositoriesCenter < ApplicationHelper::Toolbar::Basic
  button_group('repository_vmdb', [
    select(
      :repository_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :repository_refresh,
          'fa fa-refresh fa-lg',
          N_('Refresh Relationships and Power States for all items related to the selected Repositories'),
          N_('Refresh Relationships and Power States'),
          :url_parms => "main_div",
          :confirm   => N_("Refresh relationships and power states for all items related to the selected Repositories?"),
          :enabled   => false,
          :onwhen    => "1+"),
        separator,
        button(
          :repository_new,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Add a new Repository'),
          t,
          :url => "/new"),
        button(
          :repository_edit,
          'pficon pficon-edit fa-lg',
          N_('Select a single Repository to edit'),
          N_('Edit the Selected Repository'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1"),
        button(
          :repository_delete,
          'pficon pficon-delete fa-lg',
          N_('Remove Selected Repositories from the VMDB'),
          N_('Remove Repositories from the VMDB'),
          :url_parms => "main_div",
          :confirm   => N_("Warning: The selected Repositories and ALL of their components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove the selected Repositories?"),
          :enabled   => false,
          :onwhen    => "1+"),
      ]
    ),
  ])
  button_group('repository_policy', [
    select(
      :repository_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :enabled => false,
      :onwhen  => "1+",
      :items   => [
        button(
          :repository_protect,
          'pficon pficon-edit fa-lg',
          N_('Manage Policies for the selected Repositories'),
          N_('Manage Policies'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1+"),
        button(
          :repository_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for the selected Repositories'),
          N_('Edit Tags'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1+"),
      ]
    ),
  ])
end
