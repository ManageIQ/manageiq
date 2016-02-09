class ApplicationHelper::Toolbar::MiqAlertCenter < ApplicationHelper::Toolbar::Basic
  button_group('miq_alert_vmdb', [
    select(:miq_alert_vmdb_choice, 'fa fa-cog fa-lg', N_('Configuration'), N_('Configuration'),
      :items     => [
        button(:alert_edit, 'pficon pficon-edit fa-lg', N_('Edit this Alert'), N_('Edit this Alert'),
          :url_parms => "main_div"),
        button(:alert_copy, 'fa fa-files-o fa-lg', N_('Copy this Alert'), N_('Copy this Alert'),
          :confirm   => N_("Are you sure you want to copy this Alert?"),
          :url_parms => "?copy=true"),
        button(:alert_delete, 'pficon pficon-delete fa-lg', N_('Delete this Alert'), N_('Delete this Alert'),
          :url_parms => "main_div",
          :confirm   => N_("Are you sure you want to delete this Alert?")),
      ]
    ),
  ])
end
