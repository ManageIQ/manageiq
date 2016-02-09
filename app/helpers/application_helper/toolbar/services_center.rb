class ApplicationHelper::Toolbar::ServicesCenter < ApplicationHelper::Toolbar::Basic
  button_group('service_vmdb', [
    {
      :buttonSelect => "service_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :enabled      => "false",
      :onwhen       => "1+",
      :items => [
        {
          :button       => "service_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Selected Service"),
          :title        => N_("Select a single service to edit"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1",
        },
        {
          :button       => "service_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove Services from the VMDB"),
          :title        => N_("Remove selected Services from the VMDB"),
          :url_parms    => "main_div",
          :confirm      => N_("Warning: The selected Services and ALL of their components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove the selected Services?"),
          :enabled      => "false",
          :onwhen       => "1+",
        },
        {
          :separator    => nil,
        },
        {
          :button       => "service_ownership",
          :icon         => "pficon pficon-user fa-lg",
          :text         => N_("Set Ownership"),
          :title        => N_("Set Ownership for the selected Services"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1+",
        },
      ]
    },
  ])
  button_group('service_policy', [
    {
      :buttonSelect => "service_policy_choice",
      :icon         => "fa fa-shield fa-lg",
      :title        => N_("Policy"),
      :text         => N_("Policy"),
      :enabled      => "false",
      :onwhen       => "1+",
      :items => [
        {
          :button       => "service_tag",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Tags"),
          :title        => N_("Edit tags for the selected Items"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1+",
        },
      ]
    },
  ])
  button_group('service_lifecycle', [
    {
      :buttonSelect => "service_lifecycle_choice",
      :icon         => "fa fa-recycle fa-lg",
      :title        => N_("Lifecycle"),
      :text         => N_("Lifecycle"),
      :enabled      => "false",
      :onwhen       => "1+",
      :items => [
        {
          :button       => "service_retire",
          :icon         => "fa fa-clock-o fa-lg",
          :text         => N_("Set Retirement Dates"),
          :title        => N_("Set Retirement Dates for the selected items"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1+",
        },
        {
          :button       => "service_retire_now",
          :icon         => "fa fa-clock-o fa-lg",
          :text         => N_("Retire selected items"),
          :title        => N_("Retire the selected items"),
          :url_parms    => "main_div",
          :confirm      => N_("Retire the selected items?"),
          :enabled      => "false",
          :onwhen       => "1+",
        },
      ]
    },
  ])
end
