class ApplicationHelper::Toolbar::MiqPolicyCenter < ApplicationHelper::Toolbar::Basic
  button_group('policy_vmdb', [
    select(
      :policy_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :policy_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit Basic Info, Scope, and Notes'),
          t,
          :url_parms => "?typ=basic",
          :klass     => ApplicationHelper::Button::ReadOnly),
        button(
          :policy_copy,
          'fa fa-files-o fa-lg',
          proc do
            _('Copy this Policy to new Policy [%{new_policy_description}]') % {
              :new_policy_description => truncate("Copy of #{@policy.description}", :length => 255, :omission => "")
            }
          end,
          proc do
            _('Copy this %{policy_type} Policy') % {:policy_type => ui_lookup(:model => @policy.towhat)}
          end,
          :confirm   => proc do
                          _("Are you sure you want to create Policy [%{new_policy_description}] from this Policy?") % {
                            :new_policy_description => truncate("Copy of #{@policy.description}", :length => 255, :omission => "")
                          }
                        end,
          :url_parms => "main_div"),
        button(
          :policy_delete,
          'pficon pficon-delete fa-lg',
          t = proc do
            _('Delete this %{policy_type} Policy') % {:policy_type => ui_lookup(:model => @policy.towhat)}
          end,
          t,
          :url_parms => "main_div",
          :klass     => ApplicationHelper::Button::ReadOnly,
          :confirm   => proc { _("Are you sure you want to delete this %{policy_type} Policy?") % {:policy_type => ui_lookup(:model => @policy.towhat)} }),
        button(
          :condition_edit,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Create a new Condition assigned to this Policy'),
          t,
          :url_parms => "?typ=new",
          :klass     => ApplicationHelper::Button::ReadOnly),
        button(
          :policy_edit_conditions,
          'pficon pficon-edit fa-lg',
          t = N_('Edit this Policy\'s Condition assignments'),
          t,
          :url_parms => "?typ=conditions",
          :klass     => ApplicationHelper::Button::ReadOnly),
        button(
          :policy_edit_events,
          'pficon pficon-edit fa-lg',
          t = N_('Edit this Policy\'s Event assignments'),
          t,
          :url_parms => "?typ=events",
          :klass     => ApplicationHelper::Button::ReadOnly),
      ]
    ),
  ])
end
