class ApplicationHelper::Toolbar::UsersCenter < ApplicationHelper::Toolbar::Basic
  button_group('user_vmdb', [
    select(
      :user_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :rbac_user_add,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Add a new User'),
          t),
        button(
          :rbac_user_edit,
          'pficon pficon-edit fa-lg',
          N_('Select a single User to edit'),
          N_('Edit the selected User'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1"),
        button(
          :rbac_user_copy,
          'fa fa-files-o fa-lg',
          N_('Select a single User to copy'),
          N_('Copy the selected User to a new User'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1"),
        button(
          :rbac_user_delete,
          'pficon pficon-delete fa-lg',
          N_('Select one or more Users to delete'),
          N_('Delete selected Users'),
          :url_parms => "main_div",
          :confirm   => N_("Delete all selected Users?"),
          :enabled   => false,
          :onwhen    => "1+"),
      ]
    ),
  ])
  button_group('rbac_user_policy', [
    select(
      :rbac_user_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :enabled => false,
      :onwhen  => "1+",
      :items => [
        button(
          :rbac_user_tags_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit \'#{session[:customer_name]}\' Tags for the selected Users'),
          t,
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1+"),
      ]
    ),
  ])
end
