class ApplicationHelper::Toolbar::MiqReportCenter < ApplicationHelper::Toolbar::Basic
  button_group('report_run', [
    button(
      :miq_report_run,
      'fa fa-cog fa-lg',
      N_('Queue this Report to be generated'),
      N_('Queue')),
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
          t),
        button(
          :miq_report_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit this Report'),
          t),
        button(
          :miq_report_copy,
          'fa fa-files-o fa-lg',
          t = N_('Copy this Report'),
          t),
        button(
          :saved_report_delete,
          'pficon pficon-delete fa-lg',
          t = N_('Delete this Saved Report from the Database'),
          t,
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1+",
          :confirm   => N_("The selected Saved Reports will be permanently removed from the database. Are you sure you want to delete this saved Report?")),
        button(
          :miq_report_delete,
          'pficon pficon-delete fa-lg',
          t = N_('Delete this Report from the Database'),
          t,
          :url_parms => "&refresh=y",
          :confirm   => N_("The selected Reports will be permanently removed from the database. Are you sure you want to delete this Report?")),
        button(
          :miq_report_schedule_add,
          'fa fa-clock-o fa-lg',
          t = N_('Add a new Schedule'),
          t),
      ]
    ),
  ])
end
