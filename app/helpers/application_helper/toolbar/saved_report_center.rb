class ApplicationHelper::Toolbar::SavedReportCenter < ApplicationHelper::Toolbar::Basic
  button_group('saved_report_vmdb', [
    {
      :buttonSelect => "saved_report_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "report_only",
          :icon         => "product product-report fa-lg",
          :text         => N_("Show full screen Report"),
          :title        => N_("Show full screen Report"),
          :url          => "/report_only",
          :popup        => true,
          :confirm      => N_("This will show the entire report (all rows) in your browser.  Do you want to proceed?"),
        },
        {
          :button       => "saved_report_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Delete this Saved Report from the Database"),
          :title        => N_("Delete this Saved Report from the Database"),
          :url_parms    => "&refresh=y",
          :confirm      => N_("Warning: This Saved Report and ALL of its components will be permanently removed from the VMDB.  Are you sure you want to delete this Saved Report?"),
        },
      ]
    },
  ])
end
