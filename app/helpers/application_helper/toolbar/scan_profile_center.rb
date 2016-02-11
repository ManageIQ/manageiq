class ApplicationHelper::Toolbar::ScanProfileCenter < ApplicationHelper::Toolbar::Basic
  button_group('scan_vmdb', [
    select(
      :scan_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :ap_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit this Analysis Profile'),
          t),
        button(
          :ap_copy,
          'fa fa-files-o fa-lg',
          t = N_('Copy this selected Analysis Profile'),
          t,
          :url_parms => "?typ=copy"),
        button(
          :ap_delete,
          'pficon pficon-delete fa-lg',
          t = N_('Delete this Analysis Profile from the VMDB'),
          t,
          :url_parms => "&refresh=y",
          :confirm   => N_("Warning: This Analysis Profile and ALL of its components will be permanently removed from the VMDB.  Are you sure you want to delete this Analysis Profile?")),
      ]
    ),
  ])
end
