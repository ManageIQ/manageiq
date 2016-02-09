class ApplicationHelper::Toolbar::MiqAeClassCenter < ApplicationHelper::Toolbar::Basic
  button_group('miq_ae_class_vmdb', [
    select(:miq_ae_class_vmdb_choice, 'fa fa-cog fa-lg', N_('Configuration'), N_('Configuration'),
      :items     => [
        button(:miq_ae_class_edit, 'pficon pficon-edit fa-lg', N_('Edit this Class'), N_('Edit this Class')),
        button(:miq_ae_class_copy, 'fa fa-files-o fa-lg', N_('Copy this Class'), N_('Copy this Class')),
        button(:miq_ae_class_delete, 'pficon pficon-delete fa-lg', N_('Remove this Class'), N_('Remove this Class'),
          :url_parms => "&refresh=y",
          :confirm   => N_("Are you sure you want to remove this Class?")),
      ]
    ),
  ])
end
