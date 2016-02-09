class ApplicationHelper::Toolbar::MiqPolicyProfileCenter < ApplicationHelper::Toolbar::Basic
  button_group('policy_profile_vmdb', [
    select(:policy_profile_vmdb_choice, 'fa fa-cog fa-lg', N_('Configuration'), N_('Configuration'),
      :items     => [
        button(:profile_edit, 'pficon pficon-edit fa-lg', N_('Edit this Policy Profile'), N_('Edit this Policy Profile'),
          :url_parms => "main_div"),
        button(:profile_delete, 'pficon pficon-delete fa-lg', N_('Remove this Policy Profile'), N_('Remove this Policy Profile'),
          :url_parms => "main_div",
          :confirm   => N_("Are you sure you want to remove this Policy Profile?")),
      ]
    ),
  ])
end
