class ApplicationHelper::Toolbar::MiqWidgetCenter < ApplicationHelper::Toolbar::Basic
  button_group('widget_vmdb', [
    {
      :buttonSelect => "widget_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "widget_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit this Widget"),
          :title        => N_("Edit this Widget"),
        },
        {
          :button       => "widget_copy",
          :icon         => "fa fa-files-o fa-lg",
          :text         => N_("Copy this Widget"),
          :title        => N_("Copy this Widget"),
        },
        {
          :button       => "widget_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Delete this Widget from the Database"),
          :title        => N_("Delete this Widget from the Database"),
          :url_parms    => "&refresh=y",
          :confirm      => N_("Warning: This Widget and ALL of its components will be permanently removed from the VMDB.  Are you sure you want to delete this Widget?"),
        },
        {
          :separator    => nil,
        },
        {
          :button       => "widget_generate_content",
          :icon         => "fa fa-cog fa-lg",
          :confirm      => N_("Are you sure you want initiate content generation for this Widget now?"),
          :text         => N_("Generate Widget content now"),
          :title        => N_("Generate Widget content now"),
        },
      ]
    },
  ])
end
