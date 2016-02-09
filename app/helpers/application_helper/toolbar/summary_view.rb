class ApplicationHelper::Toolbar::SummaryView < ApplicationHelper::Toolbar::Basic
  button_group('summary_download', [
    {
      :button       => "download_view",
      :icon         => "fa fa-file-pdf-o fa-lg",
      :title        => N_("Download summary in PDF format"),
      :url          => "/show",
      :url_parms    => "?display=download_pdf",
    },
  ])
end
