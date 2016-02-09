class ApplicationHelper::Toolbar::UserRoleCenter < ApplicationHelper::Toolbar::Basic
  button_group('rbac_role_vmdb', [
    {
      :buttonSelect => "rbac_role_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "rbac_role_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit this Role"),
          :title        => N_("Edit this Role"),
        },
        {
          :button       => "rbac_role_copy",
          :icon         => "fa fa-files-o fa-lg",
          :text         => N_("Copy this Role to a new Role"),
          :title        => N_("Copy this Role to a new Role"),
        },
        {
          :button       => "rbac_role_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Delete this Role"),
          :title        => N_("Delete this Role"),
          :url_parms    => "&refresh=y",
          :confirm      => N_("Are you sure you want to delete this Role?"),
        },
      ]
    },
  ])
end
