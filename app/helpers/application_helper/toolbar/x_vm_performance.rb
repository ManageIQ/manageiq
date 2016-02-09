class ApplicationHelper::Toolbar::XVmPerformance < ApplicationHelper::Toolbar::Basic
  button_group('perf_tasks', [
    {
      :button       => "vm_perf_refresh",
      :icon         => "fa fa-refresh fa-lg",
      :title        => N_("Initiate refresh of recent C&U data"),
      :confirm      => N_("Initiate refresh of recent C&U data?"),
    },
    {
      :button       => "vm_perf_reload",
      :icon         => "fa fa-repeat fa-lg",
      :title        => N_("Reload the charts from the most recent C&U data"),
    },
  ])
end
