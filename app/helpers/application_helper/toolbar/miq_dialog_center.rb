class ApplicationHelper::Toolbar::MiqDialogCenter < ApplicationHelper::Toolbar::Basic
  button_group('miq_dialog_vmdb', [
    select(:host_vmdb_choice, 'fa fa-cog fa-lg', N_('Configuration'), N_('Configuration'),
      :items     => [
        button(:old_dialogs_edit, 'pficon pficon-edit fa-lg', N_('Edit this Dialog'), N_('Edit this Dialog')),
        button(:old_dialogs_copy, 'fa fa-files-o fa-lg', N_('Copy this Dialog'), N_('Copy this Dialog'),
          :url_parms => "main_div"),
        button(:old_dialogs_delete, 'pficon pficon-delete fa-lg', N_('Remove this Dialog from the VMDB'), N_('Remove from the VMDB'),
          :url_parms => "main_div",
          :confirm   => N_("Warning: This Dialog will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this Dialog?")),
      ]
    ),
  ])
end
