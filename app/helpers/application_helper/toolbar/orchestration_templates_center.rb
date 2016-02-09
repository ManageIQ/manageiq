class ApplicationHelper::Toolbar::OrchestrationTemplatesCenter < ApplicationHelper::Toolbar::Basic
  button_group('orchestration_template_vmdb', [
    {
      :buttonSelect => "orchestration_template_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "orchestration_template_add",
          :icon         => "pficon pficon-add-circle-o fa-lg",
          :text         => N_("Create new Orchestration Template"),
          :title        => N_("Create new Orchestration Template"),
        },
        {
          :button       => "orchestration_template_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit selected Orchestration Template"),
          :title        => N_("Edit selected Orchestration Template"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1",
        },
        {
          :button       => "orchestration_template_copy",
          :icon         => "fa fa-files-o fa-lg",
          :text         => N_("Copy selected Orchestration Template"),
          :title        => N_("Copy selected Orchestration Template"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1",
        },
        {
          :button       => "orchestration_template_remove",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove selected Orchestration Templates"),
          :title        => N_("Remove selected Orchestration Templates"),
          :confirm      => N_("Remove selected Orchestration Templates?"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1+",
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
          :title        => N_("Edit tags for the selected Items"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1+",
        },
      ]
    },
  ])
end
