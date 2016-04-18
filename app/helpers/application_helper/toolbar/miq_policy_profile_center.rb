class ApplicationHelper::Toolbar::MiqPolicyProfileCenter < ApplicationHelper::Toolbar::Basic
  button_group('policy_profile_vmdb', [
    select(
      :policy_profile_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :profile_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit this Policy Profile'),
          t,
          :url_parms => "main_div",
          :klass     => ApplicationHelper::Button::ReadOnly),
        button(
          :profile_delete,
          'pficon pficon-delete fa-lg',
          t = N_('Remove this Policy Profile'),
          t,
          :url_parms => "main_div",
          :klass     => ApplicationHelper::Button::ReadOnly,
          :confirm   => N_("Are you sure you want to remove this Policy Profile?")),
      ]
    ),
  ])
end
