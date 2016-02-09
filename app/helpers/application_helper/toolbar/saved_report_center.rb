class ApplicationHelper::Toolbar::SavedReportCenter < ApplicationHelper::Toolbar::Basic
  button_group('saved_report_vmdb', [
    select(:saved_report_vmdb_choice, 'fa fa-cog fa-lg', N_('Configuration'), N_('Configuration'),
      :items     => [
        button(:report_only, 'product product-report fa-lg', N_('Show full screen Report'), N_('Show full screen Report'),
          :url       => "/report_only",
          :popup     => true,
          :confirm   => N_("This will show the entire report (all rows) in your browser.  Do you want to proceed?")),
        button(:saved_report_delete, 'pficon pficon-delete fa-lg', N_('Delete this Saved Report from the Database'), N_('Delete this Saved Report from the Database'),
          :url_parms => "&refresh=y",
          :confirm   => N_("Warning: This Saved Report and ALL of its components will be permanently removed from the VMDB.  Are you sure you want to delete this Saved Report?")),
      ]
    ),
  ])
end
