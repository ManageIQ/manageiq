class ApplicationHelper::Toolbar::VmPerformance < ApplicationHelper::Toolbar::Basic
  button_group('perf_tasks', [
    {
      :button       => "perf_refresh",
      :icon         => "fa fa-refresh fa-lg",
      :title        => N_("Initiate refresh of recent C&U data"),
      :confirm      => N_("Initiate refresh of recent C&U data?"),
    },
    {
      :button       => "perf_reload",
      :icon         => "fa fa-repeat fa-lg",
      :title        => N_("Reload the charts from the most recent C&U data"),
    },
  ])
end
