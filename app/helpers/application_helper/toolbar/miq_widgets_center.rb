class ApplicationHelper::Toolbar::MiqWidgetsCenter < ApplicationHelper::Toolbar::Basic
  button_group('widget_reloading', [
    {
      :button       => "widget_refresh",
      :icon         => "fa fa-repeat fa-lg",
      :title        => N_("Reload Widgets"),
    },
  ])
  button_group('widget_vmdb', [
    {
      :buttonSelect => "widget_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "widget_new",
          :icon         => "pficon pficon-add-circle-o fa-lg",
          :text         => N_("Add a new Widget"),
          :title        => N_("Add a new Widget"),
        },
      ]
    },
  ])
end
