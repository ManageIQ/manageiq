class ApplicationHelper::Toolbar::WindowsImageCenter < ApplicationHelper::Toolbar::Basic
  button_group('pxe_wimg_vmdb', [
    select(:pxe_wimg_vmdb_choice, 'fa fa-cog fa-lg', N_('Configuration'), N_('Configuration'),
      :items     => [
        button(:pxe_wimg_edit, 'pficon pficon-edit fa-lg', N_('Edit this Windows Image'), N_('Edit this Windows Image')),
      ]
    ),
  ])
end
