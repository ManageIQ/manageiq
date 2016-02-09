class ApplicationHelper::Toolbar::OrchestrationTemplatesCenter < ApplicationHelper::Toolbar::Basic
  button_group('orchestration_template_vmdb', [
    select(:orchestration_template_vmdb_choice, 'fa fa-cog fa-lg', N_('Configuration'), N_('Configuration'),
      :items     => [
        button(:orchestration_template_add, 'pficon pficon-add-circle-o fa-lg', N_('Create new Orchestration Template'), N_('Create new Orchestration Template')),
        button(:orchestration_template_edit, 'pficon pficon-edit fa-lg', N_('Edit selected Orchestration Template'), N_('Edit selected Orchestration Template'),
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "1"),
        button(:orchestration_template_copy, 'fa fa-files-o fa-lg', N_('Copy selected Orchestration Template'), N_('Copy selected Orchestration Template'),
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "1"),
        button(:orchestration_template_remove, 'pficon pficon-delete fa-lg', N_('Remove selected Orchestration Templates'), N_('Remove selected Orchestration Templates'),
          :confirm   => N_("Remove selected Orchestration Templates?"),
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "1+"),
      ]
    ),
  ])
  button_group('orchestration_template_policy', [
    select(:orchestration_template_policy_choice, 'fa fa-shield fa-lg', N_('Policy'), N_('Policy'),
      :items     => [
        button(:orchestration_template_tag, 'pficon pficon-edit fa-lg', N_('Edit tags for the selected Items'), N_('Edit Tags'),
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "1+"),
      ]
    ),
  ])
end
