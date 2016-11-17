class ApplicationHelper::Toolbar::CloudNetworkCenter < ApplicationHelper::Toolbar::Basic
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
            :cloud_network_edit,
            'pficon pficon-edit fa-lg',
            t = N_('Edit this Cloud Network'),
            t,
            :url_parms => 'main_div'),
          button(
            :cloud_network_delete,
            'pficon pficon-delete fa-lg',
            t = N_('Delete this Cloud Network'),
            t,
            :url_parms => 'main_div',
            :confirm   => N_('Warning: This Cloud Network and ALL of its components will be removed!')
          )
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
        :items => [
          button(
            :cloud_network_tag,
            'pficon pficon-edit fa-lg',
            N_('Edit Tags for this Cloud Network'),
            N_('Edit Tags')
          )
        ]
      )
    ]
  )
end
