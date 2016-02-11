class ApplicationHelper::Toolbar::ConditionsCenter < ApplicationHelper::Toolbar::Basic
  button_group('condition_vmdb', [
    select(
      :condition_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :condition_new,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Add a New #{@sb[:folder].upcase == "VM" ? "VM" : ui_lookup(:model=>@sb[:folder])} Condition'),
          t),
      ]
    ),
  ])
end
