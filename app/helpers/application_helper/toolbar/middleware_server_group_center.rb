class ApplicationHelper::Toolbar::MiddlewareServerGroupCenter < ApplicationHelper::Toolbar::Basic
  button_group('middleware_server_group_policy', [
                 select(
                   :middleware_server_group_policy_choice,
                   'fa fa-shield fa-lg',
                   t = N_('Policy'),
                   t,
                   :enabled => "false",
                   :items   => [
                     button(
                       :middleware_server_group_tag,
                       'pficon pficon-edit fa-lg',
                       N_('Edit Tags for this Middleware Server Group'),
                       N_('Edit Tags')
                     ),
                   ]
                 ),
               ])
end
