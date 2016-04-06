class ApplicationHelper::Toolbar::OrchestrationStacksCenter < ApplicationHelper::Toolbar::Basic
  button_group('orchestration_stack_vmdb', [
    select(
      :orchestration_stack_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :orchestration_stack_delete,
          'pficon pficon-delete fa-lg',
          N_('Remove selected #{ui_lookup(:tables=>"orchestration_stack")} from the VMDB'),
          N_('Remove #{ui_lookup(:tables=>"orchestration_stack")} from the VMDB'),
          :url_parms => "main_div",
          :confirm   => N_("Warning: The selected \#{ui_lookup(:tables=>\"orchestration_stack\")} and ALL of their components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove the selected \#{ui_lookup(:tables=>\"orchestration_stack\")}?"),
          :enabled   => false,
          :onwhen    => "1+"),
      ]
    ),
  ])
  button_group('orchestration_stack_policy', [
    select(
      :orchestration_stack_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :enabled => false,
      :onwhen  => "1+",
      :items   => [
        button(
          :orchestration_stack_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for the selected #{ui_lookup(:tables=>"orchestration_stack")}'),
          N_('Edit Tags'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1+"),
      ]
    ),
  ])
  button_group('orchestration_stack_lifecycle', [
    select(
      :orchestration_stack_lifecycle_choice,
      'fa fa-recycle fa-lg',
      t = N_('Lifecycle'),
      t,
      :enabled => false,
      :onwhen  => "1+",
      :items   => [
        button(
          :orchestration_stack_retire,
          'fa fa-clock-o fa-lg',
          N_('Set Retirement Dates for the selected #{ui_lookup(:tables=>"orchestration_stack")}'),
          N_('Set Retirement Dates'),
          :enabled   => false,
          :onwhen    => "1+",
          :url_parms => "main_div"),
        button(
          :orchestration_stack_retire_now,
          'fa fa-clock-o fa-lg',
          t = N_('Retire selected #{ui_lookup(:tables => "orchestration_stack")}'),
          t,
          :confirm   => N_("Retire the selected \#{ui_lookup(:tables => \"orchestration_stack\")}?"),
          :enabled   => false,
          :onwhen    => "1+",
          :url_parms => "main_div"),
      ]
    ),
  ])
end
