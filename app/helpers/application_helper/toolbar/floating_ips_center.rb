class ApplicationHelper::Toolbar::FloatingIpsCenter < ApplicationHelper::Toolbar::Basic
  button_group(
    'floating_ip_vmdb',
    [
      select(
        :floating_ip_vmdb_choice,
        'fa fa-cog fa-lg',
        t = N_('Configuration'),
        t,
        :items => [
          button(
            :floating_ip_new,
            'pficon pficon-add-circle-o fa-lg',
            t = N_('Add a new Floating IP'),
            t),
          separator,
          # TODO: Uncomment until cross controllers show_list issue fully in place
          # https://github.com/ManageIQ/manageiq/pull/12551
          # button(
          #  :floating_ip_edit,
          #  'pficon pficon-edit fa-lg',
          #  t = N_('Manage the port association of this Floating'),
          #  t,
          #  :url_parms => 'main_div',
          #  :enabled   => false,
          #  :onwhen    => '1'),
          # button(
          #  :floating_ip_delete,
          #  'pficon pficon-delete fa-lg',
          #  t = N_('Delete selected Floating IPs'),
          #  t,
          #  :url_parms => 'main_div',
          #  :confirm   => N_('Warning: The selected Floating IPs and ALL of their components will be removed!'),
          #  :enabled   => false,
          #  :onwhen    => '1+')
        ]
      )
    ]
  )
  button_group(
    'floating_ip_policy',
    [
      select(
        :floating_ip_policy_choice,
        'fa fa-shield fa-lg',
        t = N_('Policy'),
        t,
        :enabled => false,
        :onwhen  => "1+",
        :items   => [
          button(
            :floating_ip_tag,
            'pficon pficon-edit fa-lg',
            N_('Edit Tags for the selected Floating IPs'),
            N_('Edit Tags'),
            :url_parms => "main_div",
            :enabled   => false,
            :onwhen    => "1+")
        ]
      )
    ]
  )
end
