class ApplicationHelper::Toolbar::MiqWidgetSetsCenter < ApplicationHelper::Toolbar::Basic
  button_group('db_vmdb', [
    select(:db_vmdb_choice, 'fa fa-cog fa-lg', N_('Configuration'), N_('Configuration'),
      :items     => [
        button(:db_new, 'pficon pficon-add-circle-o fa-lg', N_('Add a new Dashboard'), N_('Add a new Dashboard')),
        separator,
        button(:db_seq_edit, 'pficon pficon-edit fa-lg', N_('Edit Sequence of Dashboards'), N_('Edit Sequence of Dashboards')),
      ]
    ),
  ])
end
