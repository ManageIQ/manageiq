class ApplicationHelper::Toolbar::RepositoryCenter < ApplicationHelper::Toolbar::Basic
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
          N_('Refresh relationships and power states for all items related to this Repository'),
          N_('Refresh Relationships and Power States'),
          :confirm => N_("Refresh relationships and power states for all items related to this Repository?")),
        separator,
        button(
          :repository_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit this Repository'),
          t,
          :url => "/edit"),
        button(
          :repository_delete,
          'pficon pficon-delete fa-lg',
          N_('Remove this Repository from the VMDB'),
          N_('Remove from the VMDB'),
          :url_parms => "&refresh=y",
          :confirm   => N_("Warning: This Repository and ALL of its components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this Repository?")),
      ]
    ),
  ])
  button_group('repository_policy', [
    select(
      :repository_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :items => [
        button(
          :repository_protect,
          'pficon pficon-edit fa-lg',
          N_('Manage Policies for this Repository'),
          N_('Manage Policies')),
        button(
          :repository_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for this Repository'),
          N_('Edit Tags')),
      ]
    ),
  ])
end
