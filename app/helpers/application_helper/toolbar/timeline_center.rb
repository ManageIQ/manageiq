class ApplicationHelper::Toolbar::TimelineCenter < ApplicationHelper::Toolbar::Basic
  button_group('timeline_downloading', [
    button(
      :timeline_txt,
      'fa fa-file-text-o fa-lg',
      N_('Download this Timeline data in text format'),
      nil,
      :url => "/render_txt",
      :klass => ApplicationHelper::Button::TimelineDownload),
    button(
      :timeline_csv,
      'fa fa-file-text-o fa-lg',
      N_('Download this Timeline data in CSV format'),
      nil,
      :url => "/render_csv",
      :klass => ApplicationHelper::Button::TimelineDownload),
    button(
      :timeline_pdf,
      'fa fa-file-pdf-o fa-lg',
      N_('Download this Timeline data in PDF format'),
      nil,
      :url => "/render_pdf",
      :klass => ApplicationHelper::Button::TimelineDownload)
  ])
end
