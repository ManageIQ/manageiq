class ApplicationHelper::Toolbar::MiqAlertsCenter < ApplicationHelper::Toolbar::Basic
  button_group('miq_alert_vmdb', [
    select(:miq_alert_vmdb_choice, 'fa fa-cog fa-lg', N_('Configuration'), N_('Configuration'),
      :items     => [
        button(:alert_new, 'pficon pficon-add-circle-o fa-lg', N_('Add a New Alert'), N_('Add a New Alert')),
      ]
    ),
  ])
end
