class ApplicationHelper::Toolbar::MiqSchedulesCenter < ApplicationHelper::Toolbar::Basic
  button_group('miq_schedule_vmdb', [
    select(:miq_schedule_vmdb_choice, 'fa fa-cog fa-lg', N_('Configuration'), N_('Configuration'),
      :items     => [
        button(:schedule_add, 'pficon pficon-add-circle-o fa-lg', N_('Add a new Schedule'), N_('Add a new Schedule')),
        button(:schedule_edit, 'pficon pficon-edit fa-lg', N_('Edit the selected Schedule'), N_('Edit the selected Schedule'),
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "1"),
        button(:schedule_delete, 'pficon pficon-delete fa-lg', N_('Delete the selected Schedules from the VMDB'), N_('Delete the selected Schedules from the VMDB'),
          :url_parms => "main_div",
          :confirm   => N_("Warning: The selected Schedules and ALL of their components will be permanently removed from the VMDB.  Are you sure you want to delete the selected Schedules?"),
          :enabled   => "false",
          :onwhen    => "1+"),
        button(:schedule_enable, 'fa fa-check fa-lg', N_('Enable the selected Schedules'), N_('Enable the selected Schedules'),
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "1+"),
        button(:schedule_disable, 'fa fa-ban fa-lg', N_('Disable the selected Schedules'), N_('Disable the selected Schedules'),
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "1+"),
        separator,
        button(:schedule_run_now, 'fa fa-cog fa-lg', N_('Queue up selected Schedules to run now'), N_('Queue up selected Schedules to run now'),
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "1+"),
      ]
    ),
  ])
end
