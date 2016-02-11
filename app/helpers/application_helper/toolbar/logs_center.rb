class ApplicationHelper::Toolbar::LogsCenter < ApplicationHelper::Toolbar::Basic
  button_group('log_reloading', [
    button(
      :refresh_log,
      'fa fa-repeat fa-lg',
      N_('Reload the #{@msg_title} Log Display'),
      nil),
    button(
      :fetch_log,
      'fa fa-download fa-lg',
      N_('Download the Entire #{@msg_title} Log File'),
      nil,
      :url => "/fetch_log"),
  ])
end
