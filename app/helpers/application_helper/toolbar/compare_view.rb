class ApplicationHelper::Toolbar::CompareView < ApplicationHelper::Toolbar::Basic
  button_group('compare_view', [
    twostate(
      :compare_expanded,
      'product product-view_expanded fa-lg',
      N_('Expanded View'),
      nil,
      :klass     => ApplicationHelper::Button::ButtonWithoutRbacCheck,
      :url => "compare_compress"),
    twostate(
      :compare_compressed,
      'fa fa-bars fa-rotate-90 fa-lg',
      N_('Compressed View'),
      nil,
      :klass     => ApplicationHelper::Button::ButtonWithoutRbacCheck,
      :url => "compare_compress"),
  ])
  button_group('compare_downloading', [
    select(
      :compare_download_choice,
      'fa fa-download fa-lg',
      N_('Download'),
      nil,
      :items => [
        button(
          :compare_download_text,
          'fa fa-file-text-o fa-lg',
          N_('Download comparison report in text format'),
          N_('Download as Text'),
          :url => "/compare_to_txt"),
        button(
          :compare_download_csv,
          'fa fa-file-text-o fa-lg',
          N_('Download comparison report in CSV format'),
          N_('Download as CSV'),
          :url => "/compare_to_csv"),
        button(
          :compare_download_pdf,
          'fa fa-file-pdf-o fa-lg',
          N_('Download comparison report in PDF format'),
          N_('Download as PDF'),
          :klass     => ApplicationHelper::Button::Pdf,
          :url => "/compare_to_pdf"),
      ]
    ),
  ])
end
