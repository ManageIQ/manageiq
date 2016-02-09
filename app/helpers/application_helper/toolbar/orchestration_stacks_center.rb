class ApplicationHelper::Toolbar::OrchestrationStacksCenter < ApplicationHelper::Toolbar::Basic
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
          :text         => N_("Remove \#{ui_lookup(:tables=>\"orchestration_stack\")} from the VMDB"),
          :title        => N_("Remove selected \#{ui_lookup(:tables=>\"orchestration_stack\")} from the VMDB"),
          :url_parms    => "main_div",
          :confirm      => N_("Warning: The selected \#{ui_lookup(:tables=>\"orchestration_stack\")} and ALL of their components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove the selected \#{ui_lookup(:tables=>\"orchestration_stack\")}?"),
          :enabled      => "false",
          :onwhen       => "1+",
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
      :enabled      => "false",
      :onwhen       => "1+",
      :items => [
        {
          :button       => "orchestration_stack_tag",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Tags"),
          :title        => N_("Edit Tags for the selected \#{ui_lookup(:tables=>\"orchestration_stack\")}"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1+",
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
      :enabled      => "false",
      :onwhen       => "1+",
      :items => [
        {
          :button       => "orchestration_stack_retire",
          :icon         => "fa fa-clock-o fa-lg",
          :text         => N_("Set Retirement Dates"),
          :title        => N_("Set Retirement Dates for the selected \#{ui_lookup(:tables=>\"orchestration_stack\")}"),
          :enabled      => "false",
          :onwhen       => "1+",
          :url_parms    => "main_div",
        },
        {
          :button       => "orchestration_stack_retire_now",
          :icon         => "fa fa-clock-o fa-lg",
          :text         => N_("Retire selected \#{ui_lookup(:tables => \"orchestration_stack\")}"),
          :title        => N_("Retire selected \#{ui_lookup(:tables => \"orchestration_stack\")}"),
          :confirm      => N_("Retire the selected \#{ui_lookup(:tables => \"orchestration_stack\")}?"),
          :enabled      => "false",
          :onwhen       => "1+",
          :url_parms    => "main_div",
        },
      ]
    },
  ])
end
