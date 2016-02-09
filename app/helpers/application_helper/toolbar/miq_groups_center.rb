class ApplicationHelper::Toolbar::MiqGroupsCenter < ApplicationHelper::Toolbar::Basic
  button_group('rbac_group_vmdb', [
    {
      :buttonSelect => "rbac_group_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "rbac_group_add",
          :icon         => "pficon pficon-add-circle-o fa-lg",
          :text         => N_("Add a new Group"),
          :title        => N_("Add a new Group"),
        },
        {
          :button       => "rbac_group_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit the selected Group"),
          :title        => N_("Select a single Group to edit"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1",
        },
        {
          :button       => "rbac_group_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Delete selected Groups"),
          :title        => N_("Select one or more Groups to delete"),
          :url_parms    => "main_div",
          :confirm      => N_("Delete all selected Groups?"),
          :enabled      => "false",
          :onwhen       => "1+",
        },
        {
          :separator    => nil,
        },
        {
          :button       => "rbac_group_seq_edit",
          :icon         => "pficon pficon-edit fa-lg-assign",
          :text         => N_("Edit Sequence of User Groups for LDAP Look Up"),
          :title        => N_("Edit Sequence of User Groups for LDAP Look Up"),
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
          :text         => N_("Edit '\#{session[:customer_name]}' Tags for the selected Groups"),
          :title        => N_("Edit '\#{session[:customer_name]}' Tags for the selected Groups"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1+",
        },
      ]
    },
  ])
end
