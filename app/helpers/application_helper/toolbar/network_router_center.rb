class ApplicationHelper::Toolbar::NetworkRouterCenter < ApplicationHelper::Toolbar::Basic
  button_group(
    'network_router_vmdb',
    [
      select(
        :network_router_vmdb_choice,
        'fa fa-cog fa-lg',
        t = N_('Configuration'),
        t,
        :items => [
          button(
            :network_router_edit,
            'pficon pficon-edit fa-lg',
            t = N_('Edit this Router'),
            t,
            :url_parms => 'main_div'
          ),
          button(
            :network_router_delete,
            'pficon pficon-delete fa-lg',
            t = N_('Delete this Router'),
            t,
            :url_parms => 'main_div',
            :confirm   => N_('Warning: This Router and ALL of its components will be removed!'),
          )
        ]
      )
    ]
  )
  button_group(
    'network_router_policy',
    [
      select(
        :network_router_policy_choice,
        'fa fa-shield fa-lg',
        t = N_('Policy'),
        t,
        :items => [
          button(
            :network_router_tag,
            'pficon pficon-edit fa-lg',
            N_('Edit Tags for this Network Router'),
            N_('Edit Tags'),
          )
        ]
      )
    ]
  )
end
