class ApplicationHelper::Toolbar::UserCenter < ApplicationHelper::Toolbar::Basic
  button_group('user_vmdb', [
    {
      :buttonSelect => "user_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "rbac_user_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit this User"),
          :title        => N_("Edit this User"),
        },
        {
          :button       => "rbac_user_copy",
          :icon         => "fa fa-files-o fa-lg",
          :text         => N_("Copy this User to a new User"),
          :title        => N_("Copy this User to a new User"),
        },
        {
          :button       => "rbac_user_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Delete this User"),
          :title        => N_("Delete this User"),
          :url_parms    => "&refresh=y",
          :confirm      => N_("Are you sure you want to delete this User?"),
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
          :text         => N_("Edit '\#{session[:customer_name]}' Tags for this User"),
          :title        => N_("Edit '\#{session[:customer_name]}' Tags for this User"),
        },
      ]
    },
  ])
end
