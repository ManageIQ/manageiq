class ApplicationHelper::Toolbar::ZoneCenter < ApplicationHelper::Toolbar::Basic
  button_group('zone_vmdb', [
    select(:zone_vmdb_choice, 'fa fa-cog fa-lg', N_('Configuration'), N_('Configuration'),
      :items     => [
        button(:zone_edit, 'pficon pficon-edit fa-lg', N_('Edit this Zone'), N_('Edit this Zone')),
        button(:zone_delete, 'pficon pficon-delete fa-lg', N_('Delete this Zone'), N_('Delete this Zone'),
          :url_parms => "&refresh=y",
          :confirm   => N_("Are you sure you want to delete this Zone?")),
      ]
    ),
  ])
end
