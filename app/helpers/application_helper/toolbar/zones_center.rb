class ApplicationHelper::Toolbar::ZonesCenter < ApplicationHelper::Toolbar::Basic
  button_group('scan_vmdb', [
    {
      :buttonSelect => "zone_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "zone_new",
          :icon         => "pficon pficon-add-circle-o fa-lg",
          :text         => N_("Add a new Zone"),
          :title        => N_("Add a new Zone"),
        },
      ]
    },
  ])
end
