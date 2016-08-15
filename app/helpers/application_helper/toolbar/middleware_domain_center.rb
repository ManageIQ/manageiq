class ApplicationHelper::Toolbar::MiddlewareDomainCenter < ApplicationHelper::Toolbar::Basic
  button_group('middleware_domain_policy', [
                 select(
                   :middleware_domain_policy_choice,
                   'fa fa-shield fa-lg',
                   t = N_('Policy'),
                   t,
                   :enabled => "false",
                   :items   => [
                     button(
                       :middleware_domain_tag,
                       'pficon pficon-edit fa-lg',
                       N_('Edit Tags for this Middleware Domain'),
                       N_('Edit Tags')
                     ),
                   ]
                 ),
               ])
end
