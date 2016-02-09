class ApplicationHelper::Toolbar::TimelineCenter < ApplicationHelper::Toolbar::Basic
  button_group('timeline_downloading', [
    {
      :button       => "timeline_txt",
      :icon         => "fa fa-file-text-o fa-lg",
      :title        => N_("Download this Timeline data in text format"),
      :url          => "/render_txt",
    },
    {
      :button       => "timeline_csv",
      :icon         => "fa fa-file-text-o fa-lg",
      :title        => N_("Download this Timeline data in CSV format"),
      :url          => "/render_csv",
    },
    {
      :button       => "timeline_pdf",
      :icon         => "fa fa-file-pdf-o fa-lg",
      :title        => N_("Download this Timeline data in PDF format"),
      :url          => "/render_pdf",
    },
  ])
end
