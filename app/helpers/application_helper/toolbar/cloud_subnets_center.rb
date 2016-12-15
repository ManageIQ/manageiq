class ApplicationHelper::Toolbar::CloudSubnetsCenter < ApplicationHelper::Toolbar::Basic
  button_group('cloud_subnet_vmdb', [
    select(
      :cloud_subnet_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :cloud_subnet_new,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Add a new Cloud Subnet'),
          t,
        ),
        separator,
        # TODO: Uncomment until cross controllers show_list issue fully in place
        # https://github.com/ManageIQ/manageiq/pull/12551
        # button(
        #  :cloud_subnet_edit,
        #  'pficon pficon-edit fa-lg',
        #  t = N_('Edit selected Cloud Subnet'),
        #  t,
        #  :url_parms => 'main_div',
        #  :enabled   => false,
        #  :onwhen    => '1'
        # ),
        # button(
        #  :cloud_subnet_delete,
        #  'pficon pficon-delete fa-lg',
        #  t = N_('Delete selected Cloud Subnets'),
        #  t,
        #  :url_parms => 'main_div',
        #  :confirm   => N_('Warning: The selected Cloud Subnets and ALL of their components will be removed!'),
        #  :enabled   => false,
        #  :onwhen    => '1+'
        # ),
      ]
    )])

  button_group('cloud_subnet_policy', [
    select(
      :cloud_subnet_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :enabled => false,
      :onwhen  => "1+",
      :items   => [
        button(
          :cloud_subnet_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for the selected Cloud Subnets'),
          N_('Edit Tags'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1+"
        ),
      ]
    ),
  ])
end
