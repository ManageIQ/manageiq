class ApplicationHelper::Toolbar::MiqGroupCenter < ApplicationHelper::Toolbar::Basic
  button_group('rbac_group_vmdb', [
    {
      :buttonSelect => "rbac_group_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "rbac_group_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit this Group"),
          :title        => N_("Edit this Group"),
        },
        {
          :button       => "rbac_group_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Delete this Group"),
          :title        => N_("Delete this Group"),
          :url_parms    => "&refresh=y",
          :confirm      => N_("Are you sure you want to delete this Group?"),
        },
      ]
    },
  ])
  button_group('rbac_group_policy', [
    {
      :buttonSelect => "rbac_group_policy_choice",
      :icon         => "fa fa-shield fa-lg",
      :title        => N_("Policy"),
      :text         => N_("Policy"),
      :items => [
        {
          :button       => "rbac_group_tags_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit '\#{session[:customer_name]}' Tags for this Group"),
          :title        => N_("Edit '\#{session[:customer_name]}' Tags for this Group"),
        },
      ]
    },
  ])
end
