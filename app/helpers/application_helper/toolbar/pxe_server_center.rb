class ApplicationHelper::Toolbar::PxeServerCenter < ApplicationHelper::Toolbar::Basic
  button_group('pxe_server_vmdb', [
    select(
      :pxe_server_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :pxe_server_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit this PXE Server'),
          t),
        button(
          :pxe_server_delete,
          'pficon pficon-delete fa-lg',
          t = N_('Remove this PXE Server from the VMDB'),
          t,
          :url_parms => "&refresh=y",
          :confirm   => N_("Warning: This PXE Server and ALL of its components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this PXE Server?")),
        separator,
        button(
          :pxe_server_refresh,
          'fa fa-refresh fa-lg',
          N_('Refresh Relationships for this PXE Server'),
          N_('Refresh Relationships'),
          :confirm => N_("Refresh Relationships for this PXE Server?")),
      ]
    ),
  ])
end
