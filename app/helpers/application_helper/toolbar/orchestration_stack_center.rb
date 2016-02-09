class ApplicationHelper::Toolbar::OrchestrationStackCenter < ApplicationHelper::Toolbar::Basic
  button_group('orchestration_stack_vmdb', [
    {
      :buttonSelect => "orchestration_stack_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "orchestration_stack_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove this \#{ui_lookup(:table=>\"orchestration_stack\")} from the VMDB"),
          :title        => N_("Remove this \#{ui_lookup(:table=>\"orchestration_stack\")} from the VMDB"),
          :url_parms    => "&refresh=y",
          :confirm      => N_("Warning: This \#{ui_lookup(:table=>\"orchestration_stack\")} and ALL of its components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this \#{ui_lookup(:table=>\"orchestration_stack\")}?"),
        },
      ]
    },
  ])
  button_group('orchestration_stack_policy', [
    {
      :buttonSelect => "orchestration_stack_policy_choice",
      :icon         => "fa fa-shield fa-lg",
      :title        => N_("Policy"),
      :text         => N_("Policy"),
      :items => [
        {
          :button       => "orchestration_stack_tag",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Tags"),
          :title        => N_("Edit Tags for this \#{ui_lookup(:tables=>\"orchestration_stack\")}"),
        },
      ]
    },
  ])
  button_group('orchestration_stack_lifecycle', [
    {
      :buttonSelect => "orchestration_stack_lifecycle_choice",
      :icon         => "fa fa-recycle fa-lg",
      :title        => N_("Lifecycle"),
      :text         => N_("Lifecycle"),
      :items => [
        {
          :button       => "orchestration_stack_retire",
          :icon         => "fa fa-clock-o fa-lg",
          :text         => N_("Set Retirement Date"),
          :title        => N_("Set Retirement Dates for this Orchestration Stack"),
        },
        {
          :button       => "orchestration_stack_retire_now",
          :icon         => "fa fa-clock-o fa-lg",
          :text         => N_("Retire this Orchestration Stack"),
          :title        => N_("Retire this Orchestration Stack"),
          :confirm      => N_("Retire this Orchestration Stack"),
        },
      ]
    },
  ])
end
