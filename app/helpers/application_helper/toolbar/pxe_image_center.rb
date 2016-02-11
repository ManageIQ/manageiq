class ApplicationHelper::Toolbar::PxeImageCenter < ApplicationHelper::Toolbar::Basic
  button_group('pxe_image_vmdb', [
    select(
      :pxe_image_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :pxe_image_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit this PXE Image'),
          t),
      ]
    ),
  ])
end
