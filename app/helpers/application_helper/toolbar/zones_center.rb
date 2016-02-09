class ApplicationHelper::Toolbar::ZonesCenter < ApplicationHelper::Toolbar::Basic
  button_group('scan_vmdb', [
    select(:zone_vmdb_choice, 'fa fa-cog fa-lg', N_('Configuration'), N_('Configuration'),
      :items     => [
        button(:zone_new, 'pficon pficon-add-circle-o fa-lg', N_('Add a new Zone'), N_('Add a new Zone')),
      ]
    ),
  ])
end
