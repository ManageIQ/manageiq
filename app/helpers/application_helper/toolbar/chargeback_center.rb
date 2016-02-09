class ApplicationHelper::Toolbar::ChargebackCenter < ApplicationHelper::Toolbar::Basic
  button_group('chargeback_download_main', [
    {
      :buttonSelect => "chargeback_download_choice",
      :icon         => "fa fa-download fa-lg",
      :title        => N_("Download"),
      :items => [
        {
          :button       => "chargeback_download_text",
          :icon         => "fa fa-file-text-o fa-lg",
          :title        => N_("Download this report in text format"),
          :text         => N_("Download as Text"),
          :url          => "/render_txt",
        },
        {
          :button       => "chargeback_download_csv",
          :icon         => "fa fa-file-text-o fa-lg",
          :title        => N_("Download this report in CSV format"),
          :text         => N_("Download as CSV"),
          :url          => "/render_csv",
        },
        {
          :button       => "chargeback_download_pdf",
          :icon         => "fa fa-file-pdf-o fa-lg",
          :title        => N_("Download this report in PDF format"),
          :text         => N_("Download as PDF"),
          :url          => "/render_pdf",
        },
      ]
    },
    {
      :button       => "chargeback_report_only",
      :icon         => "product product-report fa-lg",
      :url          => "/report_only",
      :popup        => true,
      :title        => N_("Show full screen report"),
      :confirm      => N_("This will show the entire report (all rows) in your browser.  Do you want to proceed?"),
    },
  ])
  button_group('chargeback_vmdb', [
    {
      :buttonSelect => "chargeback_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "chargeback_rates_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit this Chargeback Rate"),
          :title        => N_("Edit this Chargeback Rate"),
          :url_parms    => "main_div",
        },
        {
          :button       => "chargeback_rates_copy",
          :icon         => "fa fa-files-o fa-lg",
          :title        => N_("Copy this Chargeback Rate"),
          :text         => N_("Copy this Chargeback Rate"),
          :url_parms    => "main_div",
        },
        {
          :button       => "chargeback_rates_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove from the VMDB"),
          :title        => N_("Remove this Chargeback Rate from the VMDB"),
          :url_parms    => "main_div",
          :confirm      => N_("Warning: This Chargeback Rate will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this Chargeback Rate?"),
        },
      ]
    },
  ])
end
