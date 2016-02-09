class ApplicationHelper::Toolbar::MiqPolicyCenter < ApplicationHelper::Toolbar::Basic
  button_group('policy_vmdb', [
    select(:policy_vmdb_choice, 'fa fa-cog fa-lg', N_('Configuration'), N_('Configuration'),
      :items     => [
        button(:policy_edit, 'pficon pficon-edit fa-lg', N_('Edit Basic Info, Scope, and Notes'), N_('Edit Basic Info, Scope, and Notes'),
          :url_parms => "?typ=basic"),
        button(:policy_copy, 'fa fa-files-o fa-lg', N_('Copy this Policy to new Policy [#{truncate("Copy of #{@policy.description}", :length => 255, :omission => "")}]'), N_('Copy this #{ui_lookup(:model=>@policy.towhat)} Policy'),
          :confirm   => N_("Are you sure you want to create Policy [\#{truncate(\"Copy of \#{@policy.description}\", :length => 255, :omission => \"\")}] from this Policy?"),
          :url_parms => "main_div"),
        button(:policy_delete, 'pficon pficon-delete fa-lg', N_('Delete this #{ui_lookup(:model=>@policy.towhat)} Policy'), N_('Delete this #{ui_lookup(:model=>@policy.towhat)} Policy'),
          :url_parms => "main_div",
          :confirm   => N_("Are you sure you want to delete this \#{ui_lookup(:model=>@policy.towhat)} Policy?")),
        button(:condition_edit, 'pficon pficon-add-circle-o fa-lg', N_('Create a new Condition assigned to this Policy'), N_('Create a new Condition assigned to this Policy'),
          :url_parms => "?typ=new"),
        button(:policy_edit_conditions, 'pficon pficon-edit fa-lg', N_('Edit this Policy's Condition assignments'), N_('Edit this Policy's Condition assignments'),
          :url_parms => "?typ=conditions"),
        button(:policy_edit_events, 'pficon pficon-edit fa-lg', N_('Edit this Policy's Event assignments'), N_('Edit this Policy's Event assignments'),
          :url_parms => "?typ=events"),
      ]
    ),
  ])
end
