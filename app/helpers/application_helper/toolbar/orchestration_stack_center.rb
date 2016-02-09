class ApplicationHelper::Toolbar::OrchestrationStackCenter < ApplicationHelper::Toolbar::Basic
  button_group('orchestration_stack_vmdb', [
    select(:orchestration_stack_vmdb_choice, 'fa fa-cog fa-lg', N_('Configuration'), N_('Configuration'),
      :items     => [
        button(:orchestration_stack_delete, 'pficon pficon-delete fa-lg', N_('Remove this #{ui_lookup(:table=>"orchestration_stack")} from the VMDB'), N_('Remove this #{ui_lookup(:table=>"orchestration_stack")} from the VMDB'),
          :url_parms => "&refresh=y",
          :confirm   => N_("Warning: This \#{ui_lookup(:table=>\"orchestration_stack\")} and ALL of its components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this \#{ui_lookup(:table=>\"orchestration_stack\")}?")),
      ]
    ),
  ])
  button_group('orchestration_stack_policy', [
    select(:orchestration_stack_policy_choice, 'fa fa-shield fa-lg', N_('Policy'), N_('Policy'),
      :items     => [
        button(:orchestration_stack_tag, 'pficon pficon-edit fa-lg', N_('Edit Tags for this #{ui_lookup(:tables=>"orchestration_stack")}'), N_('Edit Tags')),
      ]
    ),
  ])
  button_group('orchestration_stack_lifecycle', [
    select(:orchestration_stack_lifecycle_choice, 'fa fa-recycle fa-lg', N_('Lifecycle'), N_('Lifecycle'),
      :items     => [
        button(:orchestration_stack_retire, 'fa fa-clock-o fa-lg', N_('Set Retirement Dates for this Orchestration Stack'), N_('Set Retirement Date')),
        button(:orchestration_stack_retire_now, 'fa fa-clock-o fa-lg', N_('Retire this Orchestration Stack'), N_('Retire this Orchestration Stack'),
          :confirm   => N_("Retire this Orchestration Stack")),
      ]
    ),
  ])
end
