class ApplicationHelper::Toolbar::UserRoleCenter < ApplicationHelper::Toolbar::Basic
  button_group('rbac_role_vmdb', [
    select(
      :rbac_role_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :rbac_role_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit this Role'),
          t),
        button(
          :rbac_role_copy,
          'fa fa-files-o fa-lg',
          t = N_('Copy this Role to a new Role'),
          t),
        button(
          :rbac_role_delete,
          'pficon pficon-delete fa-lg',
          t = N_('Delete this Role'),
          t,
          :url_parms => "&refresh=y",
          :confirm   => N_("Are you sure you want to delete this Role?")),
      ]
    ),
  ])
end
