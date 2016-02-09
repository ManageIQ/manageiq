class ApplicationHelper::Toolbar::TasksCenter < ApplicationHelper::Toolbar::Basic
  button_group('miq_task_reloading', [
    {
      :button       => "miq_task_reload",
      :icon         => "fa fa-repeat fa-lg",
      :text         => N_("Reload"),
      :title        => N_("Reload the current display"),
      :url_parms    => "main_div",
    },
  ])
  button_group('miq_task_delete', [
    {
      :buttonSelect => "miq_task_delete_choice",
      :icon         => "pficon pficon-delete fa-lg",
      :title        => N_("Delete Tasks"),
      :enabled      => "true",
      :items => [
        {
          :button       => "miq_task_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Delete"),
          :title        => N_("Delete selected tasks from the VMDB"),
          :url_parms    => "main_div",
          :confirm      => N_("Warning: The selected tasks will be permanently removed from the database. Are you sure you want to delete the selected tasks?"),
          :enabled      => "false",
          :onwhen       => "1+",
        },
        {
          :button       => "miq_task_deleteolder",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Delete Older"),
          :title        => N_("Delete tasks older than the selected task"),
          :url_parms    => "main_div",
          :confirm      => N_("Warning: Tasks that are older than selected task will be permanently removed from the database. Are you sure you want to delete older tasks?"),
          :enabled      => "false",
          :onwhen       => "1",
        },
        {
          :button       => "miq_task_deleteall",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Delete All"),
          :title        => N_("Delete all finished tasks"),
          :url_parms    => "main_div",
          :confirm      => N_("Warning: Finished tasks will be permanently removed from the database. Are you sure you want to delete all finished tasks?"),
          :enabled      => "true",
        },
      ]
    },
  ])
  button_group('miq_task_editing', [
    {
      :button       => "miq_task_canceljob",
      :icon         => "fa fa-ban fa-lg",
      :text         => N_("Cancel Job"),
      :title        => N_("Cancel the selected task"),
      :url_parms    => "main_div",
      :confirm      => N_("Warning: The selected task will be cancelled. Are you sure you want to cancel the task?"),
      :enabled      => "false",
      :onwhen       => "1",
    },
  ])
end
