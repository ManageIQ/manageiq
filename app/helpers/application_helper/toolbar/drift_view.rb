class ApplicationHelper::Toolbar::DriftView < ApplicationHelper::Toolbar::Basic
  button_group('compare_view', [
    twostate(
      :drift_expanded,
      'product product-view_expanded fa-lg',
      N_('Expanded View'),
      nil,
      :url => "drift_compress"),
    twostate(
      :drift_compressed,
      'fa fa-bars fa-rotate-90 fa-lg',
      N_('Compressed View'),
      nil,
      :url => "drift_compress"),
  ])
  button_group('drift_downloading', [
    select(
      :drift_download_choice,
      'fa fa-download fa-lg',
      N_('Download'),
      nil,
      :items => [
        button(
          :drift_download_txt,
          'fa fa-file-text-o fa-lg',
          N_('Download comparison report in text format'),
          N_('Download as Text'),
          :url => "/drift_to_txt"),
        button(
          :drift_download_csv,
          'fa fa-file-text-o fa-lg',
          N_('Download comparison report in CSV format'),
          N_('Download as CSV'),
          :url => "/drift_to_csv"),
        button(
          :drift_pdf,
          'fa fa-file-pdf-o fa-lg',
          N_('Download comparison report in PDF format'),
          N_('Download as PDF'),
          :klass => ApplicationHelper::Button::Pdf,
          :url   => "/drift_to_pdf"),
      ]
    ),
  ])
end
