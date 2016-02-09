class ApplicationHelper::Toolbar::UserRoleCenter < ApplicationHelper::Toolbar::Basic
  button_group('rbac_role_vmdb', [
    select(:rbac_role_vmdb_choice, 'fa fa-cog fa-lg', N_('Configuration'), N_('Configuration'),
      :items     => [
        button(:rbac_role_edit, 'pficon pficon-edit fa-lg', N_('Edit this Role'), N_('Edit this Role')),
        button(:rbac_role_copy, 'fa fa-files-o fa-lg', N_('Copy this Role to a new Role'), N_('Copy this Role to a new Role')),
        button(:rbac_role_delete, 'pficon pficon-delete fa-lg', N_('Delete this Role'), N_('Delete this Role'),
          :url_parms => "&refresh=y",
          :confirm   => N_("Are you sure you want to delete this Role?")),
      ]
    ),
  ])
end
