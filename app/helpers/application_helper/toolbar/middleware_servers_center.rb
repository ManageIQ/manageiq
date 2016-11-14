# noinspection ALL
class ApplicationHelper::Toolbar::MiddlewareServersCenter < ApplicationHelper::Toolbar::Basic
  button_group('middleware_server_policy', [
    select(
      :middleware_server_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :enabled => false,
      :onwhen  => "1+",
      :items   => [
        button(
          :middleware_server_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for these Middleware Servers'),
          N_('Edit Tags'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1+"),
      ]
    ),
  ])
  button_group('middleware_server_operations', [
    select(
      :middleware_server_power_choice,
      'fa fa-power-off fa-lg',
      t = N_('Power'),
      t,
      :enabled => false,
      :onwhen  => "1+",
      :items   => [
        button(
          :middleware_server_reload,
          nil,
          N_('Reload these Middleware Servers'),
          N_('Reload Server'),
          :image     => 'guest_restart',
          :url_parms => 'main_div',
          :confirm   => N_('Do you want to reload selected servers?'),
          :enabled   => false,
          :onwhen    => '1+'),
      ]
    ),
  ])
end
