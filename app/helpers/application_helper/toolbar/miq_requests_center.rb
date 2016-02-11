class ApplicationHelper::Toolbar::MiqRequestsCenter < ApplicationHelper::Toolbar::Basic
  button_group('miq_request_reloading', [
    button(
      :miq_request_reload,
      'fa fa-repeat fa-lg',
      N_('Reload the current display'),
      N_('Reload'),
      :url_parms => "main_div"),
  ])
end
