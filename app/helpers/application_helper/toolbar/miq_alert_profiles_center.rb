class ApplicationHelper::Toolbar::MiqAlertProfilesCenter < ApplicationHelper::Toolbar::Basic
  button_group('miq_alert_profile_vmdb', [
    select(
      :miq_alert_profile_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :alert_profile_new,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Add a New #{ui_lookup(:model=>@sb[:folder])} Alert Profile'),
          t),
      ]
    ),
  ])
end
