class ApplicationHelper::Toolbar::SavedReportsCenter < ApplicationHelper::Toolbar::Basic
  button_group('saved_report_reloading', [
    {
      :button       => "reload",
      :icon         => "fa fa-repeat fa-lg",
      :title        => N_("Reload selected Reports"),
      :url          => "reload",
    },
  ])
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
          :enabled      => "false",
          :onwhen       => "1",
          :url          => "/report_only",
          :popup        => true,
          :confirm      => N_("This will show the entire report (all rows) in your browser.  Do you want to proceed?"),
        },
        {
          :button       => "saved_report_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Delete selected Saved Reports"),
          :title        => N_("Delete selected Saved Reports"),
          :url_parms    => "main_div",
          :confirm      => N_("The selected Saved Reports will be permanently removed from the database. Are you sure you want to delete the selected Saved Reports?"),
          :enabled      => "false",
          :onwhen       => "1+",
        },
      ]
    },
  ])
end
