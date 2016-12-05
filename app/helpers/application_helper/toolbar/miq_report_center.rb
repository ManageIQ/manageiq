class ApplicationHelper::Toolbar::MiqReportCenter < ApplicationHelper::Toolbar::Basic
  button_group('report_run', [
    button(
      :miq_report_run,
      'fa fa-play-circle-o fa-lg',
      N_('Queue this Report to be generated'),
      N_('Queue'),
      :klass => ApplicationHelper::Button::MiqReportAction),
  ])
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
        button(
          :miq_report_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit this Report'),
          t,
          :klass => ApplicationHelper::Button::MiqReportEdit),
        button(
          :miq_report_copy,
          'fa fa-files-o fa-lg',
          t = N_('Copy this Report'),
          t,
          :klass => ApplicationHelper::Button::MiqReportAction),
        button(
          :saved_report_delete,
          'pficon pficon-delete fa-lg',
          t = N_('Delete this Saved Report from the Database'),
          t,
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1+",
          :confirm   => N_("Warning: The selected Saved Reports will be permanently removed from the database!"),
          :klass     => ApplicationHelper::Button::SavedReportDelete),
        button(
          :miq_report_delete,
          'pficon pficon-delete fa-lg',
          t = N_('Delete this Report from the Database'),
          t,
          :url_parms => "&refresh=y",
          :confirm   => N_("Warning: The selected Reports will be permanently removed from the database!"),
          :klass     => ApplicationHelper::Button::MiqReportEdit),
        button(
          :miq_report_schedule_add,
          'fa fa-clock-o fa-lg',
          t = N_('Add a new Schedule'),
          t,
          :klass => ApplicationHelper::Button::MiqReportAction),
      ]
    ),
  ])
end
