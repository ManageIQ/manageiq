class ApplicationHelper::Toolbar::DialogsCenter < ApplicationHelper::Toolbar::Basic
  button_group('dialog_vmdb', [
    select(
      :dialog_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :dialog_new,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Add a new Dialog'),
          t),
        button(
          :dialog_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit the selected Dialog'),
          t,
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1"),
        button(
          :dialog_copy,
          'fa fa-files-o fa-lg',
          t = N_('Copy the selected Dialog to a new Dialog'),
          t,
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1"),
        button(
          :dialog_delete,
          'pficon pficon-delete fa-lg',
          t = N_('Remove selected Dialogs from the VMDB'),
          t,
          :url_parms => "main_div",
          :confirm   => N_("Warning: The selected Dialog will be permanently removed from the Virtual Management Database.  Are you sure you want to remove the selected Dialogs?"),
          :enabled   => false,
          :onwhen    => "1+"),
      ]
    ),
  ])
end
