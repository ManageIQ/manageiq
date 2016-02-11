class ApplicationHelper::Toolbar::OrchestrationTemplateCenter < ApplicationHelper::Toolbar::Basic
  button_group('orchestration_template_vmdb', [
    select(
      :orchestration_template_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :service_dialog_from_ot,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Create Service Dialog from Orchestration Template'),
          t),
        separator,
        button(
          :orchestration_template_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit this Orchestration Template'),
          t),
        button(
          :orchestration_template_copy,
          'fa fa-files-o fa-lg',
          t = N_('Copy this Orchestration Template'),
          t),
        button(
          :orchestration_template_remove,
          'pficon pficon-delete fa-lg',
          t = N_('Remove this Orchestration Template'),
          t,
          :confirm => N_("Remove this Orchestration Template?")),
      ]
    ),
  ])
  button_group('orchestration_template_policy', [
    select(
      :orchestration_template_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :items => [
        button(
          :orchestration_template_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for this Orchestration Template'),
          N_('Edit Tags')),
      ]
    ),
  ])
end
