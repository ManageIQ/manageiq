class ApplicationHelper::Toolbar::CloudNetworksCenter < ApplicationHelper::Toolbar::Basic
  button_group(
    'cloud_network_vmdb',
    [
      select(
        :cloud_network_vmdb_choice,
        'fa fa-cog fa-lg',
        t = N_('Configuration'),
        t,
        :items => [
          button(
            :cloud_network_new,
            'pficon pficon-add-circle-o fa-lg',
            t = N_('Add a new Cloud Network'),
            t),
          separator,
          # TODO: Restore when cross controllers show_list issue fully in place
          # https://github.com/ManageIQ/manageiq/pull/12551
          #button(
          #  :cloud_network_edit,
          #  'pficon pficon-edit fa-lg',
          #  t = N_('Edit selected Cloud Network'),
          #  t,
          #  :url_parms => 'main_div',
          #  :enabled   => false,
          #  :onwhen    => '1'),
          #button(
          #  :cloud_network_delete,
          #  'pficon pficon-delete fa-lg',
          #  t = N_('Delete selected Cloud Networks'),
          #  t,
          #  :url_parms => 'main_div',
          #  :confirm   => N_('Warning: The selected Cloud Networks and ALL of their components will be removed!'),
          #  :enabled   => false,
          #  :onwhen    => '1+')
        ]
      )
    ]
  )
  button_group(
    'cloud_network_policy',
    [
      select(
        :cloud_network_policy_choice,
        'fa fa-shield fa-lg',
        t = N_('Policy'),
        t,
        :enabled => false,
        :onwhen  => "1+",
        :items   => [
          button(
            :cloud_network_tag,
            'pficon pficon-edit fa-lg',
            N_('Edit Tags for the selected Cloud Networks'),
            N_('Edit Tags'),
            :url_parms => "main_div",
            :enabled   => false,
            :onwhen    => "1+")
        ]
      )
    ]
  )
end
