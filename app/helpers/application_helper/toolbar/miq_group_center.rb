class ApplicationHelper::Toolbar::MiqGroupCenter < ApplicationHelper::Toolbar::Basic
  button_group('rbac_group_vmdb', [
    select(
      :rbac_group_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :rbac_group_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit this Group'),
          t),
        button(
          :rbac_group_delete,
          'pficon pficon-delete fa-lg',
          t = N_('Delete this Group'),
          t,
          :url_parms => "&refresh=y",
          :confirm   => N_("Are you sure you want to delete this Group?")),
      ]
    ),
  ])
  button_group('rbac_group_policy', [
    select(
      :rbac_group_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :items => [
        button(
          :rbac_group_tags_edit,
          'pficon pficon-edit fa-lg',
          t = proc do
            _('Edit \'%{:customer_name}\' Tags for this Group') % {:customer_name => @view_context.session[:customer_name]}
          end,
          t),
      ]
    ),
  ])
end
