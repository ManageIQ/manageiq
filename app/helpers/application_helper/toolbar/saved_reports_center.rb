class ApplicationHelper::Toolbar::SavedReportsCenter < ApplicationHelper::Toolbar::Basic
  button_group('saved_report_reloading', [
    button(
      :reload,
      'fa fa-repeat fa-lg',
      N_('Reload selected Reports'),
      nil,
      :url   => "reload",
      :klass => ApplicationHelper::Button::Reload)
  ])
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
          :enabled => false,
          :onwhen  => "1",
          :url     => "/report_only",
          :popup   => true,
          :confirm => N_("This will show the entire report (all rows) in your browser.  Do you want to proceed?")),
        button(
          :saved_report_delete,
          'pficon pficon-delete fa-lg',
          t = N_('Delete selected Saved Reports'),
          t,
          :url_parms => "main_div",
          :confirm   => N_("Warning: The selected Saved Reports will be permanently removed from the database!"),
          :enabled   => false,
          :onwhen    => "1+",
          :klass     => ApplicationHelper::Button::SavedReportDelete),
      ]
    ),
  ])
end
