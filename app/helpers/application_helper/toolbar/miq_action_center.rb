class ApplicationHelper::Toolbar::MiqActionCenter < ApplicationHelper::Toolbar::Basic
  button_group('miq_action_vmdb', [
    select(:miq_action_vmdb_choice, 'fa fa-cog fa-lg', N_('Configuration'), N_('Configuration'),
      :items     => [
        button(:action_edit, 'pficon pficon-edit fa-lg', N_('Edit this Action'), N_('Edit this Action'),
          :url_parms => "?type=basic"),
        button(:action_delete, 'pficon pficon-delete fa-lg', N_('Delete this Action'), N_('Delete this Action'),
          :url_parms => "main_div",
          :confirm   => N_("Are you sure you want to delete this Action?")),
      ]
    ),
  ])
end
