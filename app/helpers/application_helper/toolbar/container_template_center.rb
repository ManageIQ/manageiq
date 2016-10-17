class ApplicationHelper::Toolbar::ContainerTemplateCenter < ApplicationHelper::Toolbar::Basic
  button_group('container_template_policy', [
    select(
      :container_template_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :items => [
        button(
          :container_template_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for this Container Template'),
          N_('Edit Tags')),
      ]
    ),
  ])
end
