class ApplicationHelper::Toolbar::MiqActionsCenter < ApplicationHelper::Toolbar::Basic
  button_group('miq_action_vmdb', [
    select(:miq_action_vmdb_choice, 'fa fa-cog fa-lg', N_('Configuration'), N_('Configuration'),
      :items     => [
        button(:action_new, 'pficon pficon-add-circle-o fa-lg', N_('Add a new Action'), N_('Add a new Action')),
      ]
    ),
  ])
end
