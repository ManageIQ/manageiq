class ApplicationHelper::Toolbar::DashboardSummaryToggleView < ApplicationHelper::Toolbar::Basic
  button_group('ems_container_dashboard', [
    twostate(
      :view_dashboard,
      'fa fa-tachometer fa-1xplus',
      N_('Dashboard View'),
      nil,
      :url       => "/",
      :url_parms => "?display=dashboard"),
    twostate(
      :view_summary,
      'fa fa-th-list',
      N_('Summary View'),
      nil,
      :url       => "/",
      :url_parms => ""),
    twostate(
      :view_topology,
      'fa pficon-topology',
      N_('Topology View'),
      nil,
      :url       => "/",
      :url_parms => "?display=topology",
      :klass     => ApplicationHelper::Button::TopologyFeatureButton)
  ])
  button_group('summary_download', [
    button(
      :download_view,
      'fa fa-file-pdf-o fa-lg',
      N_('Download summary in PDF format'),
      nil,
      :klass => ApplicationHelper::Button::Pdf,
      :url       => "/show",
      :url_parms => "?display=download_pdf"
    ),
  ])
end
