class ApplicationHelper::Toolbar::ScanProfilesCenter < ApplicationHelper::Toolbar::Basic
  button_group('scan_vmdb', [
    {
      :buttonSelect => "scan_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "ap_host_edit",
          :icon         => "pficon pficon-add-circle-o fa-lg",
          :text         => N_("Add Host Analysis Profile"),
          :title        => N_("Add a new Host Analysis Profile"),
        },
        {
          :button       => "ap_vm_edit",
          :icon         => "pficon pficon-add-circle-o fa-lg",
          :text         => N_("Add VM Analysis Profile"),
          :title        => N_("Add a new VM Analysis Profile"),
        },
        {
          :button       => "ap_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit the selected Analysis Profiles"),
          :title        => N_("Edit the selected Analysis Profiles"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1",
        },
        {
          :button       => "ap_copy",
          :icon         => "fa fa-files-o fa-lg",
          :text         => N_("Copy the selected Analysis Profiles"),
          :title        => N_("Copy the selected Analysis Profiles"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1",
        },
        {
          :button       => "ap_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Delete the selected Analysis Profiles from the VMDB"),
          :title        => N_("Delete the selected Analysis Profiles from the VMDB"),
          :url_parms    => "main_div",
          :confirm      => N_("Warning: The selected Analysis Profiles and ALL of their components will be permanently removed from the VMDB.  Are you sure you want to delete the selected Analysis Profiles?"),
          :enabled      => "false",
          :onwhen       => "1+",
        },
      ]
    },
  ])
end
