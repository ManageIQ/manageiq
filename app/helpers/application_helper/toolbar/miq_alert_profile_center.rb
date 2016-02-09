class ApplicationHelper::Toolbar::MiqAlertProfileCenter < ApplicationHelper::Toolbar::Basic
  button_group('miq_alert_profile_vmdb', [
    select(:miq_alert_profile_vmdb_choice, 'fa fa-cog fa-lg', N_('Configuration'), N_('Configuration'),
      :items     => [
        button(:alert_profile_edit, 'pficon pficon-edit fa-lg', N_('Edit this Alert Profile'), N_('Edit this Alert Profile'),
          :url_parms => "main_div"),
        button(:alert_profile_assign, 'pficon pficon-edit fa-lg-assign', N_('Edit assignments for this Alert Profile'), N_('Edit assignments for this Alert Profile'),
          :url_parms => "main_div"),
        button(:alert_profile_delete, 'pficon pficon-delete fa-lg', N_('Delete this Alert Profile'), N_('Delete this Alert Profile'),
          :url_parms => "main_div",
          :confirm   => N_("Are you sure you want to delete this Alert Profile?")),
      ]
    ),
  ])
end
