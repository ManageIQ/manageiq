class ApplicationHelper::Toolbar::MiqCapacityView < ApplicationHelper::Toolbar::Basic
  button_group('miq_capacity_download_main', [
    {
      :buttonSelect => "miq_capacity_download_choice",
      :icon         => "fa fa-download fa-lg",
      :title        => N_("Download"),
      :items => [
        {
          :button       => "miq_capacity_download_text",
          :icon         => "fa fa-file-text-o fa-lg",
          :title        => N_("Download this report in text format"),
          :text         => N_("Download as Text"),
          :url          => "/\#{x_active_tree == :utilization_tree ? \"util_report\" : \"planning_report\"}_download",
          :url_parms    => "?typ=txt",
        },
        {
          :button       => "miq_capacity_download_csv",
          :icon         => "fa fa-file-text-o fa-lg",
          :title        => N_("Download this report in CSV format"),
          :text         => N_("Download as CSV"),
          :url          => "/\#{x_active_tree == :utilization_tree ? \"util_report\" : \"planning_report\"}_download",
          :url_parms    => "?typ=csv",
        },
        {
          :button       => "miq_capacity_download_pdf",
          :icon         => "fa fa-file-pdf-o fa-lg",
          :title        => N_("Download this report in PDF format"),
          :text         => N_("Download as PDF"),
          :url          => "/\#{x_active_tree == :utilization_tree ? \"util_report\" : \"planning_report\"}_download",
          :url_parms    => "?typ=pdf",
        },
      ]
    },
  ])
end
