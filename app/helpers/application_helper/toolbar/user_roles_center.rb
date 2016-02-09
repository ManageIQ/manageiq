class ApplicationHelper::Toolbar::UserRolesCenter < ApplicationHelper::Toolbar::Basic
  button_group('rbac_role_vmdb', [
    {
      :buttonSelect => "rbac_role_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "rbac_role_add",
          :icon         => "pficon pficon-add-circle-o fa-lg",
          :text         => N_("Add a new Role"),
          :title        => N_("Add a new Role"),
        },
        {
          :button       => "rbac_role_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit the selected Role"),
          :title        => N_("Select a single Role to edit"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1",
        },
        {
          :button       => "rbac_role_copy",
          :icon         => "fa fa-files-o fa-lg",
          :text         => N_("Copy the selected Role to a new Role"),
          :title        => N_("Select a single Role to copy"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1",
        },
        {
          :button       => "rbac_role_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Delete selected Roles"),
          :title        => N_("Delete the selected Roles from the VMDB"),
          :url_parms    => "main_div",
          :confirm      => N_("Delete all selected Roles?"),
          :enabled      => "false",
          :onwhen       => "1+",
        },
      ]
    },
  ])
end
