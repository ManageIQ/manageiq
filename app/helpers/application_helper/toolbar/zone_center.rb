class ApplicationHelper::Toolbar::ZoneCenter < ApplicationHelper::Toolbar::Basic
  button_group('zone_vmdb', [
    select(
      :zone_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :zone_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit this Zone'),
          t),
        button(
          :zone_delete,
          'pficon pficon-delete fa-lg',
          t = N_('Delete this Zone'),
          t,
          :url_parms => "&refresh=y",
          :confirm   => N_("Are you sure you want to delete this Zone?")),
      ]
    ),
  ])
end
