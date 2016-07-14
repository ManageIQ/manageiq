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
          t = proc do
            _('Add a New %{alert_profile_type} Alert Profile') % {:alert_profile_type => ui_lookup(:model => @sb[:folder])}
          end,
          t),
      ]
    ),
  ])
end
