class ApplicationHelper::Toolbar::XSummaryView < ApplicationHelper::Toolbar::Basic
  button_group('summary_download', [
    {
      :button       => "vm_download_pdf",
      :icon         => "fa fa-file-pdf-o fa-lg",
      :title        => N_("Download summary in PDF format"),
      :url          => "/show",
      :url_parms    => "?display=download_pdf",
    },
  ])
end
