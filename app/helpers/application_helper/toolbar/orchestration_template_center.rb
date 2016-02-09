class ApplicationHelper::Toolbar::OrchestrationTemplateCenter < ApplicationHelper::Toolbar::Basic
  button_group('orchestration_template_vmdb', [
    select(:orchestration_template_vmdb_choice, 'fa fa-cog fa-lg', N_('Configuration'), N_('Configuration'),
      :items     => [
        button(:service_dialog_from_ot, 'pficon pficon-add-circle-o fa-lg', N_('Create Service Dialog from Orchestration Template'), N_('Create Service Dialog from Orchestration Template')),
        separator,
        button(:orchestration_template_edit, 'pficon pficon-edit fa-lg', N_('Edit this Orchestration Template'), N_('Edit this Orchestration Template')),
        button(:orchestration_template_copy, 'fa fa-files-o fa-lg', N_('Copy this Orchestration Template'), N_('Copy this Orchestration Template')),
        button(:orchestration_template_remove, 'pficon pficon-delete fa-lg', N_('Remove this Orchestration Template'), N_('Remove this Orchestration Template'),
          :confirm   => N_("Remove this Orchestration Template?")),
      ]
    ),
  ])
  button_group('orchestration_template_policy', [
    select(:orchestration_template_policy_choice, 'fa fa-shield fa-lg', N_('Policy'), N_('Policy'),
      :items     => [
        button(:orchestration_template_tag, 'pficon pficon-edit fa-lg', N_('Edit Tags for this Orchestration Template'), N_('Edit Tags')),
      ]
    ),
  ])
end
