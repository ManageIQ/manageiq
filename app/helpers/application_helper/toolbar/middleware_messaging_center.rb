# noinspection RubyArgCount
class ApplicationHelper::Toolbar::MiddlewareMessagingCenter < ApplicationHelper::Toolbar::Basic
  button_group('middleware_messaging_monitoring', [
                 select(
                   :middleware_messaging_monitoring_choice,
                   'product product-monitoring fa-lg',
                   t = N_('Monitoring'),
                   t,
                   :items => [
                     button(
                       :middleware_messaging_perf,
                       'product product-monitoring fa-lg',
                       N_('Show Capacity & Utilization data for this Middleware messaging'),
                       N_('Utilization'),
                       :url => "/show_performance")
                   ]
                 ),
               ])

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
