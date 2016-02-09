class ApplicationHelper::Toolbar::SummaryViewRestful < ApplicationHelper::Toolbar::Basic
  button_group('summary_download', [
    {
      :button       => "download_view",
      :icon         => "fa fa-file-pdf-o fa-lg",
      :title        => N_("Download summary in PDF format"),
      :url          => "/",
      :url_parms    => "?display=download_pdf",
    },
  ])
end
