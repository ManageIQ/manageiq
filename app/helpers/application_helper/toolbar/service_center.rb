class ApplicationHelper::Toolbar::ServiceCenter < ApplicationHelper::Toolbar::Basic
  button_group('service_vmdb', [
    {
      :buttonSelect => "service_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :onwhen       => "1+",
      :items => [
        {
          :button       => "service_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit this Service"),
          :title        => N_("Edit this Service"),
        },
        {
          :button       => "service_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove Service from the VMDB"),
          :title        => N_("Remove this Service from the VMDB"),
          :url_parms    => "main_div",
          :confirm      => N_("Warning: This Service and ALL of their components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this Service?"),
        },
        {
          :separator    => nil,
        },
        {
          :button       => "service_ownership",
          :icon         => "pficon pficon-user fa-lg",
          :text         => N_("Set Ownership"),
          :title        => N_("Set Ownership for this Service"),
        },
        {
          :separator    => nil,
        },
        {
          :button       => "service_reconfigure",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Reconfigure this Service"),
          :title        => N_("Reconfigure the options of this Service"),
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
      :items => [
        {
          :button       => "service_tag",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Tags"),
          :url_parms    => "main_div",
          :title        => N_("Edit Tags for this Service"),
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
      :items => [
        {
          :button       => "service_retire",
          :icon         => "fa fa-clock-o fa-lg",
          :text         => N_("Set Retirement Date"),
          :title        => N_("Set Retirement Dates for this Service"),
        },
        {
          :button       => "service_retire_now",
          :icon         => "fa fa-clock-o fa-lg",
          :text         => N_("Retire this Service"),
          :title        => N_("Retire this Service"),
          :confirm      => N_("Retire this Service?"),
        },
      ]
    },
  ])
end
