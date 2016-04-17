class ApplicationHelper::Toolbar::MiqEventCenter < ApplicationHelper::Toolbar::Basic
  button_group('policy_vmdb', [
    select(
      :policy_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :event_edit,
          'pficon pficon-edit fa-lg-action',
          t = N_('Edit Actions for this Policy Event'),
          t,
          :url_parms => "main_div",
          :klass     => ApplicationHelper::Button::MiqActionModify),
      ]
    ),
  ])
end
