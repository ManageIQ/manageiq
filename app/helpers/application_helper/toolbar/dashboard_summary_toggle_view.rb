class ApplicationHelper::Toolbar::DashboardSummaryToggleView < ApplicationHelper::Toolbar::Basic
  button_group('ems_container_dashboard', [
    twostate(
      :view_dashboard,
      'fa fa-tachometer',
      N_('Dashboard View'),
      nil,
      :url       => "/show",
      :url_parms => "?display=dashboard"),
    twostate(
      :view_summary,
      'fa fa-list-alt',
      N_('Summary View'),
      nil,
      :url       => "/show",
      :url_parms => ""),
  ])
end
