class ApplicationHelper::Toolbar::MiqAlertProfileCenter < ApplicationHelper::Toolbar::Basic
  button_group('miq_alert_profile_vmdb', [
    select(
      :miq_alert_profile_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :alert_profile_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit this Alert Profile'),
          t,
          :url_parms => "main_div"),
        button(
          :alert_profile_assign,
          'pficon pficon-edit fa-lg-assign',
          t = N_('Edit assignments for this Alert Profile'),
          t,
          :url_parms => "main_div"),
        button(
          :alert_profile_delete,
          'pficon pficon-delete fa-lg',
          t = N_('Delete this Alert Profile'),
          t,
          :url_parms => "main_div",
          :confirm   => N_("Are you sure you want to delete this Alert Profile?")),
      ]
    ),
  ])
end
