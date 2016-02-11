class ApplicationHelper::Toolbar::MiqActionsCenter < ApplicationHelper::Toolbar::Basic
  button_group('miq_action_vmdb', [
    select(
      :miq_action_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :action_new,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Add a new Action'),
          t),
      ]
    ),
  ])
end
