class ApplicationHelper::Toolbar::StackOrchestrationTemplateCenter < ApplicationHelper::Toolbar::Basic
  button_group('stack_orchestration_template_vmdb', [
    select(
      :stack_orchestration_template_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :make_ot_orderable,
          'pficon pficon-edit fa-lg',
          t = N_('Make the Orchestration Template orderable'),
          t,
          :klass => ApplicationHelper::Button::OrchestrationTemplateMakeOrderable),
        button(
          :orchestration_template_copy,
          'fa fa-files-o fa-lg',
          t = N_('Copy this Orchestration Template as orderable'),
          t),
      ]
    )
  ])
end
