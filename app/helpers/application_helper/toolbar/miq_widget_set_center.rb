class ApplicationHelper::Toolbar::MiqWidgetSetCenter < ApplicationHelper::Toolbar::Basic
  button_group('db_vmdb', [
    {
      :buttonSelect => "db_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "db_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit this Dashboard"),
          :title        => N_("Edit this Dashboard"),
        },
        {
          :button       => "db_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Delete this Dashboard from the Database"),
          :title        => N_("Delete this Dashboard from the Database"),
          :url_parms    => "&refresh=y",
          :confirm      => N_("Warning: This Dashboard and ALL of its components will be permanently removed from the VMDB.  Are you sure you want to delete this Dashboard?"),
        },
      ]
    },
  ])
end
