class ApplicationHelper::Toolbar::UserCenter < ApplicationHelper::Toolbar::Basic
  button_group('user_vmdb', [
    select(:user_vmdb_choice, 'fa fa-cog fa-lg', N_('Configuration'), N_('Configuration'),
      :items     => [
        button(:rbac_user_edit, 'pficon pficon-edit fa-lg', N_('Edit this User'), N_('Edit this User')),
        button(:rbac_user_copy, 'fa fa-files-o fa-lg', N_('Copy this User to a new User'), N_('Copy this User to a new User')),
        button(:rbac_user_delete, 'pficon pficon-delete fa-lg', N_('Delete this User'), N_('Delete this User'),
          :url_parms => "&refresh=y",
          :confirm   => N_("Are you sure you want to delete this User?")),
      ]
    ),
  ])
  button_group('rbac_user_policy', [
    select(:rbac_user_policy_choice, 'fa fa-shield fa-lg', N_('Policy'), N_('Policy'),
      :items     => [
        button(:rbac_user_tags_edit, 'pficon pficon-edit fa-lg', N_('Edit '#{session[:customer_name]}' Tags for this User'), N_('Edit '#{session[:customer_name]}' Tags for this User')),
      ]
    ),
  ])
end
