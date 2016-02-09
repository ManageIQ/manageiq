class ApplicationHelper::Toolbar::DashboardSummaryToggleView < ApplicationHelper::Toolbar::Basic
  button_group('ems_container_dashboard', [
    {
      :buttonTwoState => "view_dashboard",
      :title        => N_("Dashboard View"),
      :url          => "/show",
      :url_parms    => "?display=dashboard",
      :icon         => "fa fa-tachometer",
    },
    {
      :buttonTwoState => "view_summary",
      :title        => N_("Summary View"),
      :url          => "/show",
      :url_parms    => "",
      :icon         => "fa fa-list-alt",
    },
  ])
end
