class ApplicationHelper::Toolbar::ConditionCenter < ApplicationHelper::Toolbar::Basic
  button_group('condition_vmdb', [
    select(
      :condition_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :condition_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit this Condition'),
          t,
          :url_parms => "?type=basic",
          :klass     => ApplicationHelper::Button::ReadOnly),
        button(
          :condition_copy,
          'fa fa-files-o fa-lg',
          t = N_('Copy this Condition to a new Condition'),
          t,
          :url_parms => "?copy=true"),
        button(
          :condition_policy_copy,
          'fa fa-files-o fa-lg',
          t = N_('Copy this Condition to a new Condition assigned to Policy [#{@condition_policy.description}]'),
          t,
          :url_parms => "?copy=true"),
        button(
          :condition_delete,
          'pficon pficon-delete fa-lg',
          t = N_('Delete this #{ui_lookup(:model=>@condition.towhat)} Condition'),
          t,
          :url_parms => "main_div",
          :klass     => ApplicationHelper::Button::ReadOnly,
          :confirm   => N_("Are you sure you want to delete this \#{ui_lookup(:model=>@condition.towhat)} Condition?")),
        button(
          :condition_remove,
          'pficon pficon-delete fa-lg',
          t = N_('Remove this Condition from Policy [#{@condition_policy.description}]'),
          t,
          :url_parms => "?policy_id=\#{@condition_policy.id}",
          :klass     => ApplicationHelper::Button::ReadOnly,
          :confirm   => N_("Are you sure you want to remove this Condition from Policy [\#{@condition_policy.description}]?")),
      ]
    ),
  ])
end
