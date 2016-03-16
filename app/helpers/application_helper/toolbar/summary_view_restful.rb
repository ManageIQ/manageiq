class ApplicationHelper::Toolbar::SummaryViewRestful < ApplicationHelper::Toolbar::Basic
  button_group('summary_download', [
    button(
      :download_view,
      'fa fa-file-pdf-o fa-lg',
      N_('Download summary in PDF format'),
      nil,
      :klass     => ApplicationHelper::Button::Pdf,
      :url       => "/",
      :url_parms => "?display=download_pdf"),
  ])
end
