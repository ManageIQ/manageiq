class ApplicationHelper::Toolbar::MiqPoliciesCenter < ApplicationHelper::Toolbar::Basic
  button_group('policy_vmdb', [
    select(
      :policy_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :policy_new,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Add a New #{ui_lookup(:model=>@sb[:nodeid])} #{@sb[:mode].capitalize} Policy'),
          t,
          :url_parms => "?typ=basic"),
      ]
    ),
  ])
end
