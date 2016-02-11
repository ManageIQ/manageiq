class ApplicationHelper::Toolbar::ResourcePoolCenter < ApplicationHelper::Toolbar::Basic
  button_group('resource_pool_vmdb', [
    select(
      :resource_pool_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :resource_pool_delete,
          'pficon pficon-delete fa-lg',
          N_('Remove this Resource Pool from the VMDB'),
          N_('Remove from the VMDB'),
          :url_parms => "&refresh=y",
          :confirm   => N_("Warning: This Resource Pool and ALL of its components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this Resource Pool?")),
      ]
    ),
  ])
  button_group('resource_pool_policy', [
    select(
      :resource_pool_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :items => [
        button(
          :resource_pool_protect,
          'pficon pficon-edit fa-lg',
          N_('Manage Policies for this Resource Pool'),
          N_('Manage Policies')),
        button(
          :resource_pool_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for this Resource Pool'),
          N_('Edit Tags')),
      ]
    ),
  ])
end
