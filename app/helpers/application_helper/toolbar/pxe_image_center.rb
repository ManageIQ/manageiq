class ApplicationHelper::Toolbar::PxeImageCenter < ApplicationHelper::Toolbar::Basic
  button_group('pxe_image_vmdb', [
    select(:pxe_image_vmdb_choice, 'fa fa-cog fa-lg', N_('Configuration'), N_('Configuration'),
      :items     => [
        button(:pxe_image_edit, 'pficon pficon-edit fa-lg', N_('Edit this PXE Image'), N_('Edit this PXE Image')),
      ]
    ),
  ])
end
