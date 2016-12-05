class ApplicationHelper::Toolbar::SavedReportCenter < ApplicationHelper::Toolbar::Basic
  button_group('saved_report_vmdb', [
    select(
      :saved_report_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :report_only,
          'product product-report fa-lg',
          t = N_('Show full screen Report'),
          t,
          :url     => "/report_only",
          :popup   => true,
          :confirm => N_("This will show the entire report (all rows) in your browser.  Do you want to proceed?")),
        button(
          :saved_report_delete,
          'pficon pficon-delete fa-lg',
          t = N_('Delete this Saved Report from the Database'),
          t,
          :url_parms => "&refresh=y",
          :confirm   => N_("Warning: This Saved Report and ALL of its components will be permanently removed!"),
          :klass     => ApplicationHelper::Button::SavedReportDelete),
      ]
    ),
  ])
end
