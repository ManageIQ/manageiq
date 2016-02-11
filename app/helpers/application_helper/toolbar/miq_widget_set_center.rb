class ApplicationHelper::Toolbar::MiqWidgetSetCenter < ApplicationHelper::Toolbar::Basic
  button_group('db_vmdb', [
    select(
      :db_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :db_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit this Dashboard'),
          t),
        button(
          :db_delete,
          'pficon pficon-delete fa-lg',
          t = N_('Delete this Dashboard from the Database'),
          t,
          :url_parms => "&refresh=y",
          :confirm   => N_("Warning: This Dashboard and ALL of its components will be permanently removed from the VMDB.  Are you sure you want to delete this Dashboard?")),
      ]
    ),
  ])
end
