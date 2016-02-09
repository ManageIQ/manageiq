class ApplicationHelper::Toolbar::MiqDialogCenter < ApplicationHelper::Toolbar::Basic
  button_group('miq_dialog_vmdb', [
    {
      :buttonSelect => "host_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "old_dialogs_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit this Dialog"),
          :title        => N_("Edit this Dialog"),
        },
        {
          :button       => "old_dialogs_copy",
          :icon         => "fa fa-files-o fa-lg",
          :title        => N_("Copy this Dialog"),
          :text         => N_("Copy this Dialog"),
          :url_parms    => "main_div",
        },
        {
          :button       => "old_dialogs_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove from the VMDB"),
          :title        => N_("Remove this Dialog from the VMDB"),
          :url_parms    => "main_div",
          :confirm      => N_("Warning: This Dialog will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this Dialog?"),
        },
      ]
    },
  ])
end
