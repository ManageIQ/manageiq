class ApplicationHelper::Toolbar::CompareView < ApplicationHelper::Toolbar::Basic
  button_group('compare_view', [
    {
      :buttonTwoState => "compare_expanded",
      :icon         => "product product-view_expanded fa-lg",
      :title        => N_("Expanded View"),
      :url          => "compare_compress",
    },
    {
      :buttonTwoState => "compare_compressed",
      :icon         => "fa fa-bars fa-rotate-90 fa-lg",
      :title        => N_("Compressed View"),
      :url          => "compare_compress",
    },
  ])
  button_group('compare_downloading', [
    {
      :buttonSelect => "compare_download_choice",
      :icon         => "fa fa-download fa-lg",
      :title        => N_("Download"),
      :items => [
        {
          :button       => "compare_download_txt",
          :icon         => "fa fa-file-text-o fa-lg",
          :text         => N_("Download as Text"),
          :title        => N_("Download comparison report in text format"),
          :url          => "/compare_to_txt",
        },
        {
          :button       => "compare_download_csv",
          :icon         => "fa fa-file-text-o fa-lg",
          :text         => N_("Download as CSV"),
          :title        => N_("Download comparison report in CSV format"),
          :url          => "/compare_to_csv",
        },
        {
          :button       => "download_pdf",
          :icon         => "fa fa-file-pdf-o fa-lg",
          :text         => N_("Download as PDF"),
          :title        => N_("Download comparison report in PDF format"),
          :url          => "/compare_to_pdf",
        },
      ]
    },
  ])
end
