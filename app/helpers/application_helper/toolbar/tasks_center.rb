class ApplicationHelper::Toolbar::TasksCenter < ApplicationHelper::Toolbar::Basic
  button_group('miq_task_reloading', [
    button(
      :miq_task_reload,
      'fa fa-repeat fa-lg',
      N_('Reload the current display'),
      N_('Reload'),
      :url_parms => "main_div",
      :klass     => ApplicationHelper::Button::ButtonWithoutRbacCheck),
  ])
  button_group('miq_task_delete', [
    select(
      :miq_task_delete_choice,
      'pficon pficon-delete fa-lg',
      N_('Delete Tasks'),
      nil,
      :enabled => true,
      :items   => [
        button(
          :miq_task_delete,
          'pficon pficon-delete fa-lg',
          N_('Delete selected tasks'),
          N_('Delete'),
          :url_parms => "main_div",
          :confirm   => N_("Warning: The selected tasks will be permanently removed from the database!"),
          :enabled   => false,
          :onwhen    => "1+",
          :klass     => ApplicationHelper::Button::ButtonWithoutRbacCheck),
        button(
          :miq_task_deleteolder,
          'pficon pficon-delete fa-lg',
          N_('Delete tasks older than the selected task'),
          N_('Delete Older'),
          :url_parms => "main_div",
          :confirm   => N_("Warning: Tasks that are older than selected task will be permanently removed from the database!"),
          :enabled   => false,
          :onwhen    => "1",
          :klass     => ApplicationHelper::Button::ButtonWithoutRbacCheck),
        button(
          :miq_task_deleteall,
          'pficon pficon-delete fa-lg',
          N_('Delete all finished tasks'),
          N_('Delete All'),
          :url_parms => "main_div",
          :confirm   => N_("Warning: Finished tasks will be permanently removed from the database!"),
          :enabled   => true,
          :klass     => ApplicationHelper::Button::ButtonWithoutRbacCheck),
      ]
    ),
  ])
  button_group('miq_task_editing', [
    button(
      :miq_task_canceljob,
      'fa fa-ban fa-lg',
      N_('Cancel the selected task'),
      N_('Cancel Job'),
      :url_parms => "main_div",
      :confirm   => N_("Warning: The selected task will be cancelled. Are you sure you want to cancel the task?"),
      :enabled   => false,
      :onwhen    => "1",
      :klass     => ApplicationHelper::Button::MiqTaskCanceljob),
  ])
end
