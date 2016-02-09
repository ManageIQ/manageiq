class ApplicationHelper::Toolbar::DialogsCenter < ApplicationHelper::Toolbar::Basic
  button_group('dialog_vmdb', [
    select(:dialog_vmdb_choice, 'fa fa-cog fa-lg', N_('Configuration'), N_('Configuration'),
      :items     => [
        button(:dialog_new, 'pficon pficon-add-circle-o fa-lg', N_('Add a new Dialog'), N_('Add a new Dialog')),
        button(:dialog_edit, 'pficon pficon-edit fa-lg', N_('Edit the selected Dialog'), N_('Edit the selected Dialog'),
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "1"),
        button(:dialog_copy, 'fa fa-files-o fa-lg', N_('Copy the selected Dialog to a new Dialog'), N_('Copy the selected Dialog to a new Dialog'),
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "1"),
        button(:dialog_delete, 'pficon pficon-delete fa-lg', N_('Remove selected Dialogs from the VMDB'), N_('Remove selected Dialogs from the VMDB'),
          :url_parms => "main_div",
          :confirm   => N_("Warning: The selected Dialog will be permanently removed from the Virtual Management Database.  Are you sure you want to remove the selected Dialogs?"),
          :enabled   => "false",
          :onwhen    => "1+"),
      ]
    ),
  ])
end
