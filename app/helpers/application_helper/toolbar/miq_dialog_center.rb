class ApplicationHelper::Toolbar::MiqDialogCenter < ApplicationHelper::Toolbar::Basic
  button_group('miq_dialog_vmdb', [
    select(
      :host_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :old_dialogs_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit this Dialog'),
          t,
          :klass => ApplicationHelper::Button::OldDialogsEditDelete),
        button(
          :old_dialogs_copy,
          'fa fa-files-o fa-lg',
          t = N_('Copy this Dialog'),
          t,
          :url_parms => "main_div"),
        button(
          :old_dialogs_delete,
          'pficon pficon-delete fa-lg',
          N_('Remove this Dialog from the VMDB'),
          N_('Remove from the VMDB'),
          :url_parms => "main_div",
          :confirm   => N_("Warning: This Dialog will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this Dialog?"),
          :klass     => ApplicationHelper::Button::OldDialogsEditDelete),
      ]
    ),
  ])
end
