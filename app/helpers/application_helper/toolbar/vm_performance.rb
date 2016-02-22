class ApplicationHelper::Toolbar::VmPerformance < ApplicationHelper::Toolbar::Basic
  button_group('perf_tasks', [
    button(
      :perf_refresh,
      'fa fa-refresh fa-lg',
      N_('Initiate refresh of recent C&U data'),
      nil,
      :confirm => N_("Initiate refresh of recent C&U data?")),
    button(
      :perf_reload,
      'fa fa-repeat fa-lg',
      N_('Reload the charts from the most recent C&U data'),
      nil),
  ])
end
