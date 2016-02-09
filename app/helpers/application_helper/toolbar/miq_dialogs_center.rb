class ApplicationHelper::Toolbar::MiqDialogsCenter < ApplicationHelper::Toolbar::Basic
  button_group('miq_dialog_vmdb', [
    {
      :buttonSelect => "miq_dialog_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "old_dialogs_new",
          :icon         => "pficon pficon-add-circle-o fa-lg",
          :text         => N_("Add a new Dialog"),
          :title        => N_("Add a new Dialog"),
        },
        {
          :button       => "old_dialogs_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit the selected Dialog"),
          :title        => N_("Edit the selected Dialog"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1",
        },
        {
          :button       => "old_dialogs_copy",
          :icon         => "fa fa-files-o fa-lg",
          :title        => N_("Copy the selected Dialog to a new Dialog"),
          :text         => N_("Copy the selected Dialog to a new Dialog"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1",
        },
        {
          :button       => "old_dialogs_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove selected Dialogs from the VMDB"),
          :title        => N_("Remove selected Dialogs from the VMDB"),
          :url_parms    => "main_div",
          :confirm      => N_("Warning: The selected Dialog will be permanently removed from the Virtual Management Database.  Are you sure you want to remove the selected Dialogs?"),
          :enabled      => "false",
          :onwhen       => "1+",
        },
      ]
    },
  ])
end
