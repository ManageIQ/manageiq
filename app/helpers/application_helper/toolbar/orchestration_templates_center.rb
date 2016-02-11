class ApplicationHelper::Toolbar::OrchestrationTemplatesCenter < ApplicationHelper::Toolbar::Basic
  button_group('orchestration_template_vmdb', [
    select(
      :orchestration_template_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :orchestration_template_add,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Create new Orchestration Template'),
          t),
        button(
          :orchestration_template_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit selected Orchestration Template'),
          t,
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "1"),
        button(
          :orchestration_template_copy,
          'fa fa-files-o fa-lg',
          t = N_('Copy selected Orchestration Template'),
          t,
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "1"),
        button(
          :orchestration_template_remove,
          'pficon pficon-delete fa-lg',
          t = N_('Remove selected Orchestration Templates'),
          t,
          :confirm   => N_("Remove selected Orchestration Templates?"),
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "1+"),
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
          N_('Edit tags for the selected Items'),
          N_('Edit Tags'),
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "1+"),
      ]
    ),
  ])
end
