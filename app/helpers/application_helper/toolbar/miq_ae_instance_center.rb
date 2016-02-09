class ApplicationHelper::Toolbar::MiqAeInstanceCenter < ApplicationHelper::Toolbar::Basic
  button_group('miq_ae_instance_vmdb', [
    select(:miq_ae_instance_vmdb_choice, 'fa fa-cog fa-lg', N_('Configuration'), N_('Configuration'),
      :items     => [
        button(:miq_ae_instance_edit, 'pficon pficon-edit fa-lg', N_('Edit this Instance'), N_('Edit this Instance')),
        button(:miq_ae_instance_copy, 'fa fa-files-o fa-lg', N_('Copy this Instance'), N_('Copy this Instance')),
        button(:miq_ae_instance_delete, 'pficon pficon-delete fa-lg', N_('Remove this Instance'), N_('Remove this Instance'),
          :url_parms => "&refresh=y",
          :confirm   => N_("Are you sure you want to remove this Instance?")),
      ]
    ),
  ])
end
