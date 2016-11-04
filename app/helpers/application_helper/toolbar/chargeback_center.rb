class ApplicationHelper::Toolbar::ChargebackCenter < ApplicationHelper::Toolbar::Basic
  button_group('chargeback_download_main', [
    select(
      :chargeback_download_choice,
      'fa fa-download fa-lg',
      N_('Download'),
      nil,
      :klass => ApplicationHelper::Button::ChargebackDownloadChoice,
      :items => [
        button(
          :chargeback_download_text,
          'fa fa-file-text-o fa-lg',
          N_('Download this report in text format'),
          N_('Download as Text'),
          :klass => ApplicationHelper::Button::ChargebackDownload,
          :url => "/render_txt"),
        button(
          :chargeback_download_csv,
          'fa fa-file-text-o fa-lg',
          N_('Download this report in CSV format'),
          N_('Download as CSV'),
          :klass => ApplicationHelper::Button::ChargebackDownload,
          :url => "/render_csv"),
        button(
          :chargeback_download_pdf,
          'fa fa-file-pdf-o fa-lg',
          N_('Download this report in PDF format'),
          N_('Download as PDF'),
          :klass => ApplicationHelper::Button::Pdf,
          :url => "/render_pdf"),
      ]
    ),
    button(
      :chargeback_report_only,
      'product product-report fa-lg',
      N_('Show full screen report'),
      nil,
      :klass   => ApplicationHelper::Button::ChargebackReportOnly,
      :url     => "/report_only",
      :popup   => true,
      :confirm => N_("This will show the entire report (all rows) in your browser.  Do you want to proceed?")),
  ])
  button_group('chargeback_vmdb', [
    select(
      :chargeback_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :chargeback_rates_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit this Chargeback Rate'),
          t,
          :url_parms => "main_div",
          :klass     => ApplicationHelper::Button::ChargebackRateEdit),
        button(
          :chargeback_rates_copy,
          'fa fa-files-o fa-lg',
          t = N_('Copy this Chargeback Rate'),
          t,
          :klass     => ApplicationHelper::Button::ChargebackRates,
          :url_parms => "main_div"),
        button(
          :chargeback_rates_delete,
          'pficon pficon-delete fa-lg',
          N_('Remove this Chargeback Rate from the VMDB'),
          N_('Remove from the VMDB'),
          :url_parms => "main_div",
          :confirm   => N_("Warning: This Chargeback Rate will be permanently removed!"),
          :klass     => ApplicationHelper::Button::ChargebackRateRemove),
      ]
    ),
  ])
end
