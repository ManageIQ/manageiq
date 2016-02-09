class ApplicationHelper::Toolbar::DriftsCenter < ApplicationHelper::Toolbar::Basic
  button_group('common_drift_history', [
    {
      :button       => "common_drift",
      :icon         => "product product-drift fa-lg",
      :title        => N_("Select up to 10 timestamps for Drift Analysis"),
      :url_parms    => "main_div",
      :enabled      => "false",
      :onwhen       => "2+",
    },
  ])
end
