class ApplicationHelper::Toolbar::DriftsCenter < ApplicationHelper::Toolbar::Basic
  button_group('common_drift_history', [
    button(
      :common_drift,
      'product product-drift fa-lg',
      N_('Select up to 10 timestamps for Drift Analysis'),
      nil,
      :url_parms => "main_div",
      :enabled   => "false",
      :onwhen    => "2+"),
  ])
end
