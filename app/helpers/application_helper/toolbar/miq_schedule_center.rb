class ApplicationHelper::Toolbar::MiqScheduleCenter < ApplicationHelper::Toolbar::Basic
  button_group('miq_schedule_vmdb', [
    select(:miq_schedule_vmdb_choice, 'fa fa-cog fa-lg', N_('Configuration'), N_('Configuration'),
      :items     => [
        button(:schedule_edit, 'pficon pficon-edit fa-lg', N_('Edit this Schedule'), N_('Edit this Schedule')),
        button(:schedule_delete, 'pficon pficon-delete fa-lg', N_('Delete this Schedule from the Database'), N_('Delete this Schedule from the Database'),
          :url_parms => "&refresh=y",
          :confirm   => N_("Warning: This Schedule and ALL of its components will be permanently removed from the VMDB.  Are you sure you want to delete this Schedule?")),
        separator,
        button(:schedule_run_now, 'collect', N_('Queue up this Schedule to run now'), N_('Queue up this Schedule to run now')),
      ]
    ),
  ])
end
