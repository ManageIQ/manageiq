class ApplicationHelper::Toolbar::SecurityGroupsCenter < ApplicationHelper::Toolbar::Basic
  button_group(
    'security_group_vmdb',
    [
      select(
        :security_group_vmdb_choice,
        'fa fa-cog fa-lg',
        t = N_('Configuration'),
        t,
        :items => [
          button(
            :security_group_new,
            'pficon pficon-add-circle-o fa-lg',
            t = N_('Add a new Security Group'),
            t),
          separator,
          # TODO: Uncomment until cross controllers show_list issue fully in place
          # https://github.com/ManageIQ/manageiq/pull/12551
          # button(
          #  :security_group_edit,
          #  'pficon pficon-edit fa-lg',
          #  t = N_('Edit selected Security Group'),
          #  t,
          #  :url_parms => 'main_div',
          #  :enabled   => false,
          #  :onwhen    => '1'),
          # button(
          #  :security_group_delete,
          #  'pficon pficon-delete fa-lg',
          #  t = N_('Delete selected Security Groups'),
          #  t,
          #  :url_parms => 'main_div',
          #  :confirm   => N_('Warning: The selected Security Groups and ALL of their components will be removed!'),
          #  :enabled   => false,
          #  :onwhen    => '1+')
        ]
      )
    ]
  )
  button_group('security_group_policy', [
    select(
      :security_group_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :enabled => false,
      :onwhen  => "1+",
      :items   => [
        button(
          :security_group_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for the selected Security Groups'),
          N_('Edit Tags'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1+"),
      ]
    ),
  ])
end
