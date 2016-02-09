class ApplicationHelper::Toolbar::ZoneCenter < ApplicationHelper::Toolbar::Basic
  button_group('zone_vmdb', [
    {
      :buttonSelect => "zone_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "zone_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit this Zone"),
          :title        => N_("Edit this Zone"),
        },
        {
          :button       => "zone_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Delete this Zone"),
          :title        => N_("Delete this Zone"),
          :url_parms    => "&refresh=y",
          :confirm      => N_("Are you sure you want to delete this Zone?"),
        },
      ]
    },
  ])
end
