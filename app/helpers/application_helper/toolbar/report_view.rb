class ApplicationHelper::Toolbar::ReportView < ApplicationHelper::Toolbar::Basic
  button_group('ght_main', [
    {
      :buttonTwoState => "view_graph",
      :icon         => "product product-chart",
      :title        => N_("Graph View"),
      :url          => "explorer",
      :url_parms    => "?type=graph",
    },
    {
      :buttonTwoState => "view_hybrid",
      :icon         => "fa fa fa-th-list",
      :title        => N_("Hybrid View"),
      :url          => "explorer",
      :url_parms    => "?type=hybrid",
    },
    {
      :buttonTwoState => "view_tabular",
      :icon         => "product product-report",
      :title        => N_("Tabular View"),
      :url          => "explorer",
      :url_parms    => "?type=tabular",
    },
  ])
  button_group('download_main', [
    {
      :buttonSelect => "download_choice",
      :icon         => "fa fa-download fa-lg",
      :title        => N_("Download"),
      :items => [
        {
          :button       => "render_report_txt",
          :icon         => "fa fa-file-text-o fa-lg",
          :text         => N_("Download as Text"),
          :title        => N_("Download this report in text format"),
          :url_parms    => "?render_type=txt",
        },
        {
          :button       => "render_report_csv",
          :icon         => "fa fa-file-text-o fa-lg",
          :text         => N_("Download as CSV"),
          :title        => N_("Download this report in CSV format"),
          :url_parms    => "?render_type=csv",
        },
        {
          :button       => "render_report_pdf",
          :icon         => "fa fa-file-pdf-o fa-lg",
          :text         => N_("Download as PDF"),
          :title        => N_("Download this report in PDF format"),
          :url_parms    => "?render_type=pdf",
        },
      ]
    },
  ])
end
