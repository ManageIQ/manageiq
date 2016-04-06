class ApplicationHelper::Toolbar::UserRolesCenter < ApplicationHelper::Toolbar::Basic
  button_group('rbac_role_vmdb', [
    select(
      :rbac_role_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :rbac_role_add,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Add a new Role'),
          t),
        button(
          :rbac_role_edit,
          'pficon pficon-edit fa-lg',
          N_('Select a single Role to edit'),
          N_('Edit the selected Role'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1"),
        button(
          :rbac_role_copy,
          'fa fa-files-o fa-lg',
          N_('Select a single Role to copy'),
          N_('Copy the selected Role to a new Role'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1"),
        button(
          :rbac_role_delete,
          'pficon pficon-delete fa-lg',
          N_('Delete the selected Roles from the VMDB'),
          N_('Delete selected Roles'),
          :url_parms => "main_div",
          :confirm   => N_("Delete all selected Roles?"),
          :enabled   => false,
          :onwhen    => "1+"),
      ]
    ),
  ])
end
