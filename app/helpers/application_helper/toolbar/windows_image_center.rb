class ApplicationHelper::Toolbar::WindowsImageCenter < ApplicationHelper::Toolbar::Basic
  button_group('pxe_wimg_vmdb', [
    select(
      :pxe_wimg_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :pxe_wimg_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit this Windows Image'),
          t),
      ]
    ),
  ])
end
