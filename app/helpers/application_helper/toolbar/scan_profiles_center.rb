class ApplicationHelper::Toolbar::ScanProfilesCenter < ApplicationHelper::Toolbar::Basic
  button_group('scan_vmdb', [
    select(
      :scan_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :ap_host_edit,
          'pficon pficon-add-circle-o fa-lg',
          N_('Add a new Host Analysis Profile'),
          N_('Add Host Analysis Profile')),
        button(
          :ap_vm_edit,
          'pficon pficon-add-circle-o fa-lg',
          N_('Add a new VM Analysis Profile'),
          N_('Add VM Analysis Profile')),
        button(
          :ap_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit the selected Analysis Profiles'),
          t,
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "1"),
        button(
          :ap_copy,
          'fa fa-files-o fa-lg',
          t = N_('Copy the selected Analysis Profiles'),
          t,
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "1"),
        button(
          :ap_delete,
          'pficon pficon-delete fa-lg',
          t = N_('Delete the selected Analysis Profiles from the VMDB'),
          t,
          :url_parms => "main_div",
          :confirm   => N_("Warning: The selected Analysis Profiles and ALL of their components will be permanently removed from the VMDB.  Are you sure you want to delete the selected Analysis Profiles?"),
          :enabled   => "false",
          :onwhen    => "1+"),
      ]
    ),
  ])
end
