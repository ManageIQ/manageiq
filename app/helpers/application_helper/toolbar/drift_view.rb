class ApplicationHelper::Toolbar::DriftView < ApplicationHelper::Toolbar::Basic
  button_group('compare_view', [
    {
      :buttonTwoState => "drift_expanded",
      :icon         => "product product-view_expanded fa-lg",
      :title        => N_("Expanded View"),
      :url          => "drift_compress",
    },
    {
      :buttonTwoState => "drift_compressed",
      :icon         => "fa fa-bars fa-rotate-90 fa-lg",
      :title        => N_("Compressed View"),
      :url          => "drift_compress",
    },
  ])
  button_group('drift_downloading', [
    {
      :buttonSelect => "drift_download_choice",
      :icon         => "fa fa-download fa-lg",
      :title        => N_("Download"),
      :items => [
        {
          :button       => "drift_download_txt",
          :icon         => "fa fa-file-text-o fa-lg",
          :title        => N_("Download comparison report in text format"),
          :text         => N_("Download as Text"),
          :url          => "/drift_to_txt",
        },
        {
          :button       => "drift_download_csv",
          :icon         => "fa fa-file-text-o fa-lg",
          :title        => N_("Download comparison report in CSV format"),
          :text         => N_("Download as CSV"),
          :url          => "/drift_to_csv",
        },
        {
          :button       => "drift_pdf",
          :icon         => "fa fa-file-pdf-o fa-lg",
          :title        => N_("Download comparison report in PDF format"),
          :text         => N_("Download as PDF"),
          :url          => "/drift_to_pdf",
        },
      ]
    },
  ])
end
