class ApplicationHelper::Toolbar::ConditionCenter < ApplicationHelper::Toolbar::Basic
  button_group('condition_vmdb', [
    select(:condition_vmdb_choice, 'fa fa-cog fa-lg', N_('Configuration'), N_('Configuration'),
      :items     => [
        button(:condition_edit, 'pficon pficon-edit fa-lg', N_('Edit this Condition'), N_('Edit this Condition'),
          :url_parms => "?type=basic"),
        button(:condition_copy, 'fa fa-files-o fa-lg', N_('Copy this Condition to a new Condition'), N_('Copy this Condition to a new Condition'),
          :url_parms => "?copy=true"),
        button(:condition_policy_copy, 'fa fa-files-o fa-lg', N_('Copy this Condition to a new Condition assigned to Policy [#{@condition_policy.description}]'), N_('Copy this Condition to a new Condition assigned to Policy [#{@condition_policy.description}]'),
          :url_parms => "?copy=true"),
        button(:condition_delete, 'pficon pficon-delete fa-lg', N_('Delete this #{ui_lookup(:model=>@condition.towhat)} Condition'), N_('Delete this #{ui_lookup(:model=>@condition.towhat)} Condition'),
          :url_parms => "main_div",
          :confirm   => N_("Are you sure you want to delete this \#{ui_lookup(:model=>@condition.towhat)} Condition?")),
        button(:condition_remove, 'pficon pficon-delete fa-lg', N_('Remove this Condition from Policy [#{@condition_policy.description}]'), N_('Remove this Condition from Policy [#{@condition_policy.description}]'),
          :url_parms => "?policy_id=\#{@condition_policy.id}",
          :confirm   => N_("Are you sure you want to remove this Condition from Policy [\#{@condition_policy.description}]?")),
      ]
    ),
  ])
end
