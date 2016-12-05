class ApplicationHelper::Toolbar::MiqReportsCenter < ApplicationHelper::Toolbar::Basic
  button_group('report_vmdb', [
    select(
      :report_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :miq_report_new,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Add a new Report'),
          t,
          :klass => ApplicationHelper::Button::MiqReportAction),
      ]
    ),
  ])
end
