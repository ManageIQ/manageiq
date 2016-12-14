class ApplicationHelper::Toolbar::ReportView < ApplicationHelper::Toolbar::Basic
  button_group('ght_main', [
    twostate(
      :view_graph,
      'product product-chart',
      N_('Graph View'),
      nil,
      :url       => "explorer",
      :url_parms => "?type=graph",
      :klass     => ApplicationHelper::Button::ViewGHT),
    twostate(
      :view_hybrid,
      'fa fa fa-th-list',
      N_('Hybrid View'),
      nil,
      :url       => "explorer",
      :url_parms => "?type=hybrid",
      :klass     => ApplicationHelper::Button::ViewGHT),
    twostate(
      :view_tabular,
      'product product-report',
      N_('Tabular View'),
      nil,
      :url       => "explorer",
      :url_parms => "?type=tabular",
      :klass     => ApplicationHelper::Button::ViewGHT),
  ])
  button_group('download_main', [
    select(
      :download_choice,
      'fa fa-download fa-lg',
      N_('Download'),
      nil,
      :klass => ApplicationHelper::Button::ReportDownloadChoice,
      :items => [
        button(
          :render_report_txt,
          'fa fa-file-text-o fa-lg',
          N_('Download this report in text format'),
          N_('Download as Text'),
          :url_parms => "?render_type=txt"),
        button(
          :render_report_csv,
          'fa fa-file-text-o fa-lg',
          N_('Download this report in CSV format'),
          N_('Download as CSV'),
          :url_parms => "?render_type=csv"),
        button(
          :render_report_pdf,
          'fa fa-file-pdf-o fa-lg',
          N_('Download this report in PDF format'),
          N_('Download as PDF'),
          :klass     => ApplicationHelper::Button::Pdf,
          :url_parms => "?render_type=pdf"),
      ]
    ),
  ])
end
