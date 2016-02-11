class ApplicationHelper::Toolbar::MiqCapacityView < ApplicationHelper::Toolbar::Basic
  button_group('miq_capacity_download_main', [
    select(
      :miq_capacity_download_choice,
      'fa fa-download fa-lg',
      N_('Download'),
      nil,
      :items => [
        button(
          :miq_capacity_download_text,
          'fa fa-file-text-o fa-lg',
          N_('Download this report in text format'),
          N_('Download as Text'),
          :url       => "/\#{x_active_tree == :utilization_tree ? \"util_report\" : \"planning_report\"}_download",
          :url_parms => "?typ=txt"),
        button(
          :miq_capacity_download_csv,
          'fa fa-file-text-o fa-lg',
          N_('Download this report in CSV format'),
          N_('Download as CSV'),
          :url       => "/\#{x_active_tree == :utilization_tree ? \"util_report\" : \"planning_report\"}_download",
          :url_parms => "?typ=csv"),
        button(
          :miq_capacity_download_pdf,
          'fa fa-file-pdf-o fa-lg',
          N_('Download this report in PDF format'),
          N_('Download as PDF'),
          :url       => "/\#{x_active_tree == :utilization_tree ? \"util_report\" : \"planning_report\"}_download",
          :url_parms => "?typ=pdf"),
      ]
    ),
  ])
end
