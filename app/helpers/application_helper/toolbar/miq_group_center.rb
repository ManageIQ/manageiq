class ApplicationHelper::Toolbar::MiqGroupCenter < ApplicationHelper::Toolbar::Basic
  button_group('rbac_group_vmdb', [
    select(:rbac_group_vmdb_choice, 'fa fa-cog fa-lg', N_('Configuration'), N_('Configuration'),
      :items     => [
        button(:rbac_group_edit, 'pficon pficon-edit fa-lg', N_('Edit this Group'), N_('Edit this Group')),
        button(:rbac_group_delete, 'pficon pficon-delete fa-lg', N_('Delete this Group'), N_('Delete this Group'),
          :url_parms => "&refresh=y",
          :confirm   => N_("Are you sure you want to delete this Group?")),
      ]
    ),
  ])
  button_group('rbac_group_policy', [
    select(:rbac_group_policy_choice, 'fa fa-shield fa-lg', N_('Policy'), N_('Policy'),
      :items     => [
        button(:rbac_group_tags_edit, 'pficon pficon-edit fa-lg', N_('Edit '#{session[:customer_name]}' Tags for this Group'), N_('Edit '#{session[:customer_name]}' Tags for this Group')),
      ]
    ),
  ])
end
