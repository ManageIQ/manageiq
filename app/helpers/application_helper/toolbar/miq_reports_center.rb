class ApplicationHelper::Toolbar::MiqReportsCenter < ApplicationHelper::Toolbar::Basic
  button_group('report_vmdb', [
    select(:report_vmdb_choice, 'fa fa-cog fa-lg', N_('Configuration'), N_('Configuration'),
      :items     => [
        button(:miq_report_new, 'pficon pficon-add-circle-o fa-lg', N_('Add a new Report'), N_('Add a new Report')),
      ]
    ),
  ])
end
