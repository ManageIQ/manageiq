class ApplicationHelper::Toolbar::LogsCenter < ApplicationHelper::Toolbar::Basic
  button_group('log_reloading', [
    button(
      :refresh_log,
      'fa fa-repeat fa-lg',
      proc do
        _('Reload the %{log_type} Log Display') % {:log_type => @msg_title}
      end,
      nil),
    button(
      :fetch_log,
      'fa fa-download fa-lg',
      proc do
        _('Download the Entire %{log_type} Log File') % {:log_type => @msg_title}
      end,
      nil,
      :url => "/fetch_log"),
  ])
end
