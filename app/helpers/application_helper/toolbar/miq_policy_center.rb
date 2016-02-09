class ApplicationHelper::Toolbar::MiqPolicyCenter < ApplicationHelper::Toolbar::Basic
  button_group('policy_vmdb', [
    {
      :buttonSelect => "policy_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "policy_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Basic Info, Scope, and Notes"),
          :title        => N_("Edit Basic Info, Scope, and Notes"),
          :url_parms    => "?typ=basic",
        },
        {
          :button       => "policy_copy",
          :icon         => "fa fa-files-o fa-lg",
          :text         => N_("Copy this \#{ui_lookup(:model=>@policy.towhat)} Policy"),
          :title        => N_("Copy this Policy to new Policy [\#{truncate(\"Copy of \#{@policy.description}\", :length => 255, :omission => \"\")}]"),
          :confirm      => N_("Are you sure you want to create Policy [\#{truncate(\"Copy of \#{@policy.description}\", :length => 255, :omission => \"\")}] from this Policy?"),
          :url_parms    => "main_div",
        },
        {
          :button       => "policy_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Delete this \#{ui_lookup(:model=>@policy.towhat)} Policy"),
          :title        => N_("Delete this \#{ui_lookup(:model=>@policy.towhat)} Policy"),
          :url_parms    => "main_div",
          :confirm      => N_("Are you sure you want to delete this \#{ui_lookup(:model=>@policy.towhat)} Policy?"),
        },
        {
          :button       => "condition_edit",
          :icon         => "pficon pficon-add-circle-o fa-lg",
          :text         => N_("Create a new Condition assigned to this Policy"),
          :title        => N_("Create a new Condition assigned to this Policy"),
          :url_parms    => "?typ=new",
        },
        {
          :button       => "policy_edit_conditions",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit this Policy's Condition assignments"),
          :title        => N_("Edit this Policy's Condition assignments"),
          :url_parms    => "?typ=conditions",
        },
        {
          :button       => "policy_edit_events",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit this Policy's Event assignments"),
          :title        => N_("Edit this Policy's Event assignments"),
          :url_parms    => "?typ=events",
        },
      ]
    },
  ])
end
