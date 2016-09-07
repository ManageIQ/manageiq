# noinspection RubyArgCount
class ApplicationHelper::Toolbar::MiddlewareMessagingCenter < ApplicationHelper::Toolbar::Basic
  button_group('middleware_messaging_policy', [
                 select(
                   :middleware_messaging_policy_choice,
                   'fa fa-shield fa-lg',
                   t = N_('Policy'),
                   t,
                   :enabled => "false",
                   :items   => [
                     button(
                       :middleware_messaging_tag,
                       'pficon pficon-edit fa-lg',
                       N_('Edit Tags for this Middleware messaging'),
                       N_('Edit Tags')),
                   ]
                 ),
               ])
end
