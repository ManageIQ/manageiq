class ApplicationHelper::Toolbar::DashboardSummaryToggleView < ApplicationHelper::Toolbar::Basic
  button_group('ems_container_dashboard', [
    twostate(
      :view_topology,
      'fa pficon-topology',
      N_('Topology View'),
      nil,
      :klass     => ApplicationHelper::Button::View,
      :url       => "/show",
      :url_parms => "?display=topology"),
    twostate(
      :view_dashboard,
      'fa fa-tachometer fa-1xplus',
      N_('Dashboard View'),
      nil,
      :klass     => ApplicationHelper::Button::View,
      :url       => "/show",
      :url_parms => "?display=dashboard"),
    twostate(
      :view_summary,
      'fa fa-th-list',
      N_('Summary View'),
      nil,
      :klass     => ApplicationHelper::Button::View,
      :url       => "/show",
      :url_parms => "")
  ])
end
