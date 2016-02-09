class ApplicationHelper::Toolbar::MiqEventCenter < ApplicationHelper::Toolbar::Basic
  button_group('policy_vmdb', [
    select(:policy_vmdb_choice, 'fa fa-cog fa-lg', N_('Configuration'), N_('Configuration'),
      :items     => [
        button(:event_edit, 'pficon pficon-edit fa-lg-action', N_('Edit Actions for this Policy Event'), N_('Edit Actions for this Policy Event'),
          :url_parms => "main_div"),
      ]
    ),
  ])
end
