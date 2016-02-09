class ApplicationHelper::Toolbar::IsoImageCenter < ApplicationHelper::Toolbar::Basic
  button_group('iso_image_vmdb', [
    select(:iso_image_vmdb_choice, 'fa fa-cog fa-lg', N_('Configuration'), N_('Configuration'),
      :items     => [
        button(:iso_image_edit, 'pficon pficon-edit fa-lg', N_('Edit this ISO Image'), N_('Edit this ISO Image')),
      ]
    ),
  ])
end
