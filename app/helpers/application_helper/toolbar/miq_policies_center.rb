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
          t = proc do
              _('Add a New %{model} %{mode} Policy') % {
                :model => ui_lookup(:model => @sb[:nodeid]),
                :mode  => @sb[:mode].capitalize
              }
          end,
          t,
          :url_parms => "?typ=basic"),
      ]
    ),
  ])
end
