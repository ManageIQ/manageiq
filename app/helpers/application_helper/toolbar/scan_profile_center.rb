class ApplicationHelper::Toolbar::ScanProfileCenter < ApplicationHelper::Toolbar::Basic
  button_group('scan_vmdb', [
    {
      :buttonSelect => "scan_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "ap_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit this Analysis Profile"),
          :title        => N_("Edit this Analysis Profile"),
        },
        {
          :button       => "ap_copy",
          :icon         => "fa fa-files-o fa-lg",
          :text         => N_("Copy this selected Analysis Profile"),
          :title        => N_("Copy this selected Analysis Profile"),
          :url_parms    => "?typ=copy",
        },
        {
          :button       => "ap_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Delete this Analysis Profile from the VMDB"),
          :title        => N_("Delete this Analysis Profile from the VMDB"),
          :url_parms    => "&refresh=y",
          :confirm      => N_("Warning: This Analysis Profile and ALL of its components will be permanently removed from the VMDB.  Are you sure you want to delete this Analysis Profile?"),
        },
      ]
    },
  ])
end
