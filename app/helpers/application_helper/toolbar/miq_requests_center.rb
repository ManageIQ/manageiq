class ApplicationHelper::Toolbar::MiqRequestsCenter < ApplicationHelper::Toolbar::Basic
  button_group('miq_request_reloading', [
    {
      :button       => "miq_request_reload",
      :icon         => "fa fa-repeat fa-lg",
      :text         => N_("Reload"),
      :title        => N_("Reload the current display"),
      :url_parms    => "main_div",
    },
  ])
end
