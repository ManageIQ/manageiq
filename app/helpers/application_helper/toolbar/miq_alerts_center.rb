class ApplicationHelper::Toolbar::MiqAlertsCenter < ApplicationHelper::Toolbar::Basic
  button_group('miq_alert_vmdb', [
    select(
      :miq_alert_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :alert_new,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Add a New Alert'),
          t),
      ]
    ),
  ])
end
