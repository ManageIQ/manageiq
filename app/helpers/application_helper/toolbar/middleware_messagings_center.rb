# noinspection RubyArgCount
class ApplicationHelper::Toolbar::MiddlewareMessagingsCenter < ApplicationHelper::Toolbar::Basic
  button_group('middleware_messaging_policy', [
                 select(
                   :middleware_messaging_policy_choice,
                   'fa fa-shield fa-lg',
                   t = N_('Policy'),
                   t,
                   :enabled => false,
                   :onwhen  => "1+",
                   :items   => [
                     button(
                       :middleware_messaging_tag,
                       'pficon pficon-edit fa-lg',
                       N_('Edit Tags for these Middleware mesagings'),
                       N_('Edit Tags'),
                       :url_parms => "main_div",
                       :enabled   => false,
                       :onwhen    => "1+"),
                   ]
                 ),
               ])
end
