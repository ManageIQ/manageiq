class ApplicationHelper::Toolbar::MiqWidgetSetCenter < ApplicationHelper::Toolbar::Basic
  button_group('db_vmdb', [
    select(:db_vmdb_choice, 'fa fa-cog fa-lg', N_('Configuration'), N_('Configuration'),
      :items     => [
        button(:db_edit, 'pficon pficon-edit fa-lg', N_('Edit this Dashboard'), N_('Edit this Dashboard')),
        button(:db_delete, 'pficon pficon-delete fa-lg', N_('Delete this Dashboard from the Database'), N_('Delete this Dashboard from the Database'),
          :url_parms => "&refresh=y",
          :confirm   => N_("Warning: This Dashboard and ALL of its components will be permanently removed from the VMDB.  Are you sure you want to delete this Dashboard?")),
      ]
    ),
  ])
end
