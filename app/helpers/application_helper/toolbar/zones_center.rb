class ApplicationHelper::Toolbar::ZonesCenter < ApplicationHelper::Toolbar::Basic
  button_group('scan_vmdb', [
    select(
      :zone_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :zone_new,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Add a new Zone'),
          t),
      ]
    ),
  ])
end
