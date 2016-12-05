class ApplicationHelper::Toolbar::MiqReportSchedulesCenter < ApplicationHelper::Toolbar::Basic
  button_group('miq_schedule_vmdb', [
    select(
      :miq_schedule_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :miq_report_schedule_add,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Add a new Schedule'),
          t,
          :klass => ApplicationHelper::Button::MiqReportAction),
        button(
          :miq_report_schedule_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit the selected Schedule'),
          t,
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1"),
        button(
          :miq_report_schedule_delete,
          'pficon pficon-delete fa-lg',
          t = N_('Delete the selected Schedules'),
          t,
          :url_parms => "main_div",
          :confirm   => N_("Warning: The selected Schedules and ALL of their components will be permanently removed!"),
          :enabled   => false,
          :onwhen    => "1+"),
        button(
          :miq_report_schedule_enable,
          'fa fa-check fa-lg',
          t = N_('Enable the selected Schedules'),
          t,
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1+"),
        button(
          :miq_report_schedule_disable,
          'fa fa-ban fa-lg',
          t = N_('Disable the selected Schedules'),
          t,
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1+"),
        separator,
        button(
          :miq_report_schedule_run_now,
          'fa fa-play-circle-o fa-lg',
          t = N_('Queue up selected Schedules to run now'),
          t,
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1+"),
      ]
    ),
  ])
end
