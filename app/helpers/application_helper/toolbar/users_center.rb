class ApplicationHelper::Toolbar::UsersCenter < ApplicationHelper::Toolbar::Basic
  button_group('user_vmdb', [
    {
      :buttonSelect => "user_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "rbac_user_add",
          :icon         => "pficon pficon-add-circle-o fa-lg",
          :text         => N_("Add a new User"),
          :title        => N_("Add a new User"),
        },
        {
          :button       => "rbac_user_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit the selected User"),
          :title        => N_("Select a single User to edit"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1",
        },
        {
          :button       => "rbac_user_copy",
          :icon         => "fa fa-files-o fa-lg",
          :text         => N_("Copy the selected User to a new User"),
          :title        => N_("Select a single User to copy"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1",
        },
        {
          :button       => "rbac_user_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Delete selected Users"),
          :title        => N_("Select one or more Users to delete"),
          :url_parms    => "main_div",
          :confirm      => N_("Delete all selected Users?"),
          :enabled      => "false",
          :onwhen       => "1+",
        },
      ]
    },
  ])
  button_group('rbac_user_policy', [
    {
      :buttonSelect => "rbac_user_policy_choice",
      :icon         => "fa fa-shield fa-lg",
      :title        => N_("Policy"),
      :text         => N_("Policy"),
      :items => [
        {
          :button       => "rbac_user_tags_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit '\#{session[:customer_name]}' Tags for the selected Users"),
          :title        => N_("Edit '\#{session[:customer_name]}' Tags for the selected Users"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1+",
        },
      ]
    },
  ])
end
