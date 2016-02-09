class ApplicationHelper::Toolbar::ChargebackCenter < ApplicationHelper::Toolbar::Basic
  button_group('chargeback_download_main', [
    select(:chargeback_download_choice, 'fa fa-download fa-lg', N_('Download'), nil,
      :items     => [
        button(:chargeback_download_text, 'fa fa-file-text-o fa-lg', N_('Download this report in text format'), N_('Download as Text'),
          :url       => "/render_txt"),
        button(:chargeback_download_csv, 'fa fa-file-text-o fa-lg', N_('Download this report in CSV format'), N_('Download as CSV'),
          :url       => "/render_csv"),
        button(:chargeback_download_pdf, 'fa fa-file-pdf-o fa-lg', N_('Download this report in PDF format'), N_('Download as PDF'),
          :url       => "/render_pdf"),
      ]
    ),
    button(:chargeback_report_only, 'product product-report fa-lg', N_('Show full screen report'), nil,
      :url       => "/report_only",
      :popup     => true,
      :confirm   => N_("This will show the entire report (all rows) in your browser.  Do you want to proceed?")    ),
  ])
  button_group('chargeback_vmdb', [
    select(:chargeback_vmdb_choice, 'fa fa-cog fa-lg', N_('Configuration'), N_('Configuration'),
      :items     => [
        button(:chargeback_rates_edit, 'pficon pficon-edit fa-lg', N_('Edit this Chargeback Rate'), N_('Edit this Chargeback Rate'),
          :url_parms => "main_div"),
        button(:chargeback_rates_copy, 'fa fa-files-o fa-lg', N_('Copy this Chargeback Rate'), N_('Copy this Chargeback Rate'),
          :url_parms => "main_div"),
        button(:chargeback_rates_delete, 'pficon pficon-delete fa-lg', N_('Remove this Chargeback Rate from the VMDB'), N_('Remove from the VMDB'),
          :url_parms => "main_div",
          :confirm   => N_("Warning: This Chargeback Rate will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this Chargeback Rate?")),
      ]
    ),
  ])
end
