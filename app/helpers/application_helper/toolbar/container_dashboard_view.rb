class ApplicationHelper::Toolbar::ContainerDashboardView < ApplicationHelper::Toolbar::Basic
  button_group('container_dashboard', [
    twostate(
      :view_dashboard,
      'fa fa-tachometer fa-1xplus',
      N_('Dashboard View'),
      nil,
      :url       => "/",
      :url_parms => ""),
    twostate(
        :view_topology,
        'fa pficon-topology',
        N_('Topology View'),
        nil,
        :url       => "/show",
        :url_parms => "?display=topology")
  ])
end
