class ApplicationHelper::Toolbar::XGtlView < ApplicationHelper::Toolbar::Basic
  button_group('gtl_main', [
    {
      :buttonTwoState => "view_grid",
      :title        => N_("Grid View"),
      :url          => "explorer",
      :url_parms    => "?type=grid",
      :icon         => "fa fa-th",
    },
    {
      :buttonTwoState => "view_tile",
      :title        => N_("Tile View"),
      :url          => "explorer",
      :url_parms    => "?type=tile",
      :icon         => "fa fa-th-large",
    },
    {
      :buttonTwoState => "view_list",
      :title        => N_("List View"),
      :url          => "explorer",
      :url_parms    => "?type=list",
      :icon         => "fa fa-th-list",
    },
  ])
  button_group('download_main', [
    {
      :buttonSelect => "download_choice",
      :icon         => "fa fa-download fa-lg",
      :title        => N_("Download"),
      :items => [
        {
          :button       => "download_text",
          :icon         => "fa fa-file-text-o fa-lg",
          :text         => N_("Download as Text"),
          :title        => N_("Download these items in text format"),
          :url          => "/download_data",
          :url_parms    => "?download_type=text",
        },
        {
          :button       => "download_csv",
          :icon         => "fa fa-file-text-o fa-lg",
          :text         => N_("Download as CSV"),
          :title        => N_("Download these items in CSV format"),
          :url          => "/download_data",
          :url_parms    => "?download_type=csv",
        },
        {
          :button       => "download_pdf",
          :icon         => "fa fa-file-pdf-o fa-lg",
          :text         => N_("Download as PDF"),
          :title        => N_("Download these items in PDF format"),
          :url          => "/download_data",
          :url_parms    => "?download_type=pdf",
        },
      ]
    },
  ])
end
