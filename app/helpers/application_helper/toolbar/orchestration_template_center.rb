class ApplicationHelper::Toolbar::OrchestrationTemplateCenter < ApplicationHelper::Toolbar::Basic
  button_group('orchestration_template_vmdb', [
    {
      :buttonSelect => "orchestration_template_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "service_dialog_from_ot",
          :icon         => "pficon pficon-add-circle-o fa-lg",
          :text         => N_("Create Service Dialog from Orchestration Template"),
          :title        => N_("Create Service Dialog from Orchestration Template"),
        },
        {
          :separator    => nil,
        },
        {
          :button       => "orchestration_template_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit this Orchestration Template"),
          :title        => N_("Edit this Orchestration Template"),
        },
        {
          :button       => "orchestration_template_copy",
          :icon         => "fa fa-files-o fa-lg",
          :text         => N_("Copy this Orchestration Template"),
          :title        => N_("Copy this Orchestration Template"),
        },
        {
          :button       => "orchestration_template_remove",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove this Orchestration Template"),
          :title        => N_("Remove this Orchestration Template"),
          :confirm      => N_("Remove this Orchestration Template?"),
        },
      ]
    },
  ])
  button_group('orchestration_template_policy', [
    {
      :buttonSelect => "orchestration_template_policy_choice",
      :icon         => "fa fa-shield fa-lg",
      :title        => N_("Policy"),
      :text         => N_("Policy"),
      :items => [
        {
          :button       => "orchestration_template_tag",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Tags"),
          :title        => N_("Edit Tags for this Orchestration Template"),
        },
      ]
    },
  ])
end
