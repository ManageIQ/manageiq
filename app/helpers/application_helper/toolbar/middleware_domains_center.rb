class ApplicationHelper::Toolbar::MiddlewareDomainsCenter < ApplicationHelper::Toolbar::Basic
  button_group('middleware_domains_policy', [
                 select(
                   :middleware_domain_policy_choice,
                   'fa fa-shield fa-lg',
                   t = N_('Policy'),
                   t,
                   :enabled => false,
                   :onwhen  => "1+",
                   :items   => [
                     button(
                       :middleware_domain_tag,
                       'pficon pficon-edit fa-lg',
                       N_('Edit Tags for these Middleware Domains'),
                       N_('Edit Tags'),
                       :url_parms => "main_div",
                       :enabled   => false,
                       :onwhen    => "1+",
                     ),
                   ]
                 ),
               ])
end
