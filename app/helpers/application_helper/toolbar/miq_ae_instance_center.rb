class ApplicationHelper::Toolbar::MiqAeInstanceCenter < ApplicationHelper::Toolbar::Basic
  button_group('miq_ae_instance_vmdb', [
    select(
      :miq_ae_instance_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :miq_ae_instance_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit this Instance'),
          t,
          :klass => ApplicationHelper::Button::MiqAeDefault),
        button(
          :miq_ae_instance_copy,
          'fa fa-files-o fa-lg',
          t = N_('Copy this Instance'),
          t,
          :klass => ApplicationHelper::Button::MiqAeInstanceCopy),
        button(
          :miq_ae_instance_delete,
          'pficon pficon-delete fa-lg',
          t = N_('Remove this Instance'),
          t,
          :url_parms => "&refresh=y",
          :confirm   => N_("Are you sure you want to remove this Instance?"),
          :klass     => ApplicationHelper::Button::MiqAeDefault),
      ]
    ),
  ])
end
