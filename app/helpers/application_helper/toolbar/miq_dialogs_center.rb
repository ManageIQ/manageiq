class ApplicationHelper::Toolbar::MiqDialogsCenter < ApplicationHelper::Toolbar::Basic
  button_group('miq_dialog_vmdb', [
    select(:miq_dialog_vmdb_choice, 'fa fa-cog fa-lg', N_('Configuration'), N_('Configuration'),
      :items     => [
        button(:old_dialogs_new, 'pficon pficon-add-circle-o fa-lg', N_('Add a new Dialog'), N_('Add a new Dialog')),
        button(:old_dialogs_edit, 'pficon pficon-edit fa-lg', N_('Edit the selected Dialog'), N_('Edit the selected Dialog'),
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "1"),
        button(:old_dialogs_copy, 'fa fa-files-o fa-lg', N_('Copy the selected Dialog to a new Dialog'), N_('Copy the selected Dialog to a new Dialog'),
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "1"),
        button(:old_dialogs_delete, 'pficon pficon-delete fa-lg', N_('Remove selected Dialogs from the VMDB'), N_('Remove selected Dialogs from the VMDB'),
          :url_parms => "main_div",
          :confirm   => N_("Warning: The selected Dialog will be permanently removed from the Virtual Management Database.  Are you sure you want to remove the selected Dialogs?"),
          :enabled   => "false",
          :onwhen    => "1+"),
      ]
    ),
  ])
end
