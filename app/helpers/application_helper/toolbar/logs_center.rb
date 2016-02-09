class ApplicationHelper::Toolbar::LogsCenter < ApplicationHelper::Toolbar::Basic
  button_group('log_reloading', [
    {
      :button       => "refresh_log",
      :icon         => "fa fa-repeat fa-lg",
      :title        => N_("Reload the \#{@msg_title} Log Display"),
    },
    {
      :button       => "fetch_log",
      :icon         => "fa fa-download fa-lg",
      :title        => N_("Download the Entire \#{@msg_title} Log File"),
      :url          => "/fetch_log",
    },
  ])
end
