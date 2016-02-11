class ApplicationHelper::Toolbar::MiqScheduleCenter < ApplicationHelper::Toolbar::Basic
  button_group('miq_schedule_vmdb', [
    select(
      :miq_schedule_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :schedule_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit this Schedule'),
          t),
        button(
          :schedule_delete,
          'pficon pficon-delete fa-lg',
          t = N_('Delete this Schedule from the Database'),
          t,
          :url_parms => "&refresh=y",
          :confirm   => N_("Warning: This Schedule and ALL of its components will be permanently removed from the VMDB.  Are you sure you want to delete this Schedule?")),
        separator,
        button(
          :schedule_run_now,
          'collect',
          t = N_('Queue up this Schedule to run now'),
          t),
      ]
    ),
  ])
end
