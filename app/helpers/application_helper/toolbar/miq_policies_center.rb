class ApplicationHelper::Toolbar::MiqPoliciesCenter < ApplicationHelper::Toolbar::Basic
  button_group('policy_vmdb', [
    {
      :buttonSelect => "policy_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "policy_new",
          :icon         => "pficon pficon-add-circle-o fa-lg",
          :text         => N_("Add a New \#{ui_lookup(:model=>@sb[:nodeid])} \#{@sb[:mode].capitalize} Policy"),
          :title        => N_("Add a New \#{ui_lookup(:model=>@sb[:nodeid])} \#{@sb[:mode].capitalize} Policy"),
          :url_parms    => "?typ=basic",
        },
      ]
    },
  ])
end
