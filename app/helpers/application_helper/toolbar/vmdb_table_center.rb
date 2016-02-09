class ApplicationHelper::Toolbar::VmdbTableCenter < ApplicationHelper::Toolbar::Basic
  button_group('support_reloading', [
    {
      :button       => "db_refresh",
      :icon         => "fa fa-repeat fa-lg",
      :title        => N_("Reload Current Display"),
    },
  ])
end
