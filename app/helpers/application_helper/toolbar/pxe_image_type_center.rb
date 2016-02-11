class ApplicationHelper::Toolbar::PxeImageTypeCenter < ApplicationHelper::Toolbar::Basic
  button_group('pxe_image_type_vmdb', [
    select(
      :pxe_image_type_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :pxe_image_type_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit this System Image Type'),
          t),
        button(
          :pxe_image_type_delete,
          'pficon pficon-delete fa-lg',
          t = N_('Remove this System Image Type from the VMDB'),
          t,
          :url_parms => "&refresh=y",
          :confirm   => N_("Warning: This System Image Type will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this System Image Type?")),
      ]
    ),
  ])
end
