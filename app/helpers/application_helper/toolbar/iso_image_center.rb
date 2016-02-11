class ApplicationHelper::Toolbar::IsoImageCenter < ApplicationHelper::Toolbar::Basic
  button_group('iso_image_vmdb', [
    select(
      :iso_image_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :iso_image_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit this ISO Image'),
          t),
      ]
    ),
  ])
end
