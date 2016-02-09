class ApplicationHelper::Toolbar::ConditionCenter < ApplicationHelper::Toolbar::Basic
  button_group('condition_vmdb', [
    {
      :buttonSelect => "condition_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "condition_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit this Condition"),
          :title        => N_("Edit this Condition"),
          :url_parms    => "?type=basic",
        },
        {
          :button       => "condition_copy",
          :icon         => "fa fa-files-o fa-lg",
          :text         => N_("Copy this Condition to a new Condition"),
          :title        => N_("Copy this Condition to a new Condition"),
          :url_parms    => "?copy=true",
        },
        {
          :button       => "condition_policy_copy",
          :icon         => "fa fa-files-o fa-lg",
          :text         => N_("Copy this Condition to a new Condition assigned to Policy [\#{@condition_policy.description}]"),
          :title        => N_("Copy this Condition to a new Condition assigned to Policy [\#{@condition_policy.description}]"),
          :url_parms    => "?copy=true",
        },
        {
          :button       => "condition_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Delete this \#{ui_lookup(:model=>@condition.towhat)} Condition"),
          :title        => N_("Delete this \#{ui_lookup(:model=>@condition.towhat)} Condition"),
          :url_parms    => "main_div",
          :confirm      => N_("Are you sure you want to delete this \#{ui_lookup(:model=>@condition.towhat)} Condition?"),
        },
        {
          :button       => "condition_remove",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove this Condition from Policy [\#{@condition_policy.description}]"),
          :title        => N_("Remove this Condition from Policy [\#{@condition_policy.description}]"),
          :url_parms    => "?policy_id=\#{@condition_policy.id}",
          :confirm      => N_("Are you sure you want to remove this Condition from Policy [\#{@condition_policy.description}]?"),
        },
      ]
    },
  ])
end
